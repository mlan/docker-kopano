""" movetopublicldap.py

This is an LDAP lookup extension to the move to public plugin.

The move to public plugin moves incoming messages to a folder in the public
store. If folders are missing they will be created.

A LDAP entry including:

kopanoAccount: 1
kopanoResourceType: publicStore:<public folder>

will have its email delivered to the public store in <public folder>.
The token match is case sensitive and there must be a colon ':' separating
the token and the public folder name. The folder name can contain space and
sub folders, which are distinguished using forward slash '/'.
So if we have 'kopanoResourceType: publicStore:Public Stores/public' emails will
be delivered to 'Public Folders/Public Stores/public'.

The parameters in /etc/kopano/ldap.cfg will be used for the LDAP query.
The LDAP attribute holding the token and the token itself have the following
default values, which can be modified in /etc/kopano/movetopublicldap.cfg
if desired.

ldap_public_store_attribute = kopanoResourceType
ldap_public_store_attribute_token = publicStore

"""
from sys import hexversion
from MAPI.Util import GetPublicStore
from MAPI.Struct import NEWMAIL_NOTIFICATION
from MAPI import MAPI_UNICODE, MAPI_MODIFY, OPEN_IF_EXISTS, MDB_WRITE
from MAPI.Tags import (PR_RECEIVED_BY_EMAIL_ADDRESS_W, PR_EC_COMPANY_NAME_W,
	PR_IPM_PUBLIC_FOLDERS_ENTRYID, PR_ENTRYID, PR_MAILBOX_OWNER_ENTRYID,
	IID_IMessage, IID_IExchangeManageStore)
from plugintemplates import IMapiDAgentPlugin, MP_CONTINUE, MP_STOP_SUCCESS
from zconfig import ZConfigParser
import configparser
import ldap

class KConfigParser(ZConfigParser):
	""" Extends zconfig.ZConfigParser to also allow !directive in cfg files """
	def __init__(self, configfile, defaultconfig={}):
		self.config = configparser.ConfigParser(defaults=defaultconfig,
			delimiters=('='), comment_prefixes=('#', '!'))
		self.readZConfig(configfile)

class MoveToPublic(IMapiDAgentPlugin):

	prioPreDelivery = 50

	config = {}

	CONFIGFILES = ['/etc/kopano/ldap.cfg', '/etc/kopano/movetopublicldap.cfg']

	DEFAULTCONFIG = {
		'ldap_uri': None,
		'ldap_search_base': None,
		'ldap_bind_user': None,
		'ldap_bind_passwd': None,
		'ldap_user_unique_attribute': "uid",
		'ldap_public_store_attribute': "kopanoResourceType",
		'ldap_public_store_attribute_token': "publicStore"
	}

	def __init__(self, logger):
		IMapiDAgentPlugin.__init__(self, logger)
		self.readconfig(self.CONFIGFILES, self.DEFAULTCONFIG)

	def readconfig(self, configfiles=CONFIGFILES, defaultconfig=DEFAULTCONFIG):
		""" Reads ldap.cfg and movetopublicldap.cfg into self.config """
		options = [opt.split('_', 1)[1] for opt in defaultconfig.keys()]
		config = None
		for configfile in configfiles:
			if not config:
				config = KConfigParser(configfile, defaultconfig)
			else:
				config = KConfigParser(configfile, config.options())
		self.config = config.getdict('ldap',options)
		self.logger.logDebug("*--- Config list {}".format(self.config))
		return self.config

	def searchfilter(self, recipient):
		""" (&(uid=recipient)(kopanoResourceType=publicStore:*)) """
		return ("(&({}={})({}={}:*))"
			.format(self.config['user_unique_attribute'],
			recipient,
			self.config['public_store_attribute'],
			self.config['public_store_attribute_token']))

	def searchquery(self, recipient):
		""" Query a LDAP/AD driectory server to lookup recipient using
		search_base and return public_store_attribute
		"""
		if (self.config['uri'] is None):
			self.logger.logError(("!--- ldap_uri is not defined."
				" Please check {}" .format(self.CONFIGFILES[0])))
			return None
		else:
			l = ldap.initialize(self.config['uri'])
			try:
				l.protocol_version = ldap.VERSION3
				l.simple_bind_s(self.config['bind_user'] or u'', \
					self.config['bind_passwd'] or u'')
			except ldap.SERVER_DOWN as e:
				self.logger.logError(("!--- LDAP server is not reachable {}"
				.format(e)))
				return None
			except ldap.INVALID_CREDENTIALS as e:
				self.logger.logError(("!--- Invalid LDAP credentials {}"
					" Please check {}" .format(e, self.CONFIGFILES[0])))
				l.unbind_s()
				return None
			except ldap.LDAPError as e:
				self.logger.logError("!--- LDAPError {}".format(e))
				l.unbind_s()
				return None
			try:
				result = l.search_s(self.config['search_base'], \
					ldap.SCOPE_SUBTREE, self.searchfilter(recipient), \
					[self.config['public_store_attribute']])
			except ldap.LDAPError as e:
				self.logger.logError("!--- LDAPError {}".format(e))
			l.unbind_s()
		return result

	def publicfolder(self, recipient):
		""" Check for ldap_public_store_attribute_token and return folder """
		destination_folder = []
		result = self.searchquery(recipient)
		if result:
			tokenandfolder = (result[0][1]
				.get(self.config['public_store_attribute'])[0].decode('utf-8'))
			if tokenandfolder:
				destination_folder = tokenandfolder.split(':')[1]
				if destination_folder:
					self.logger.logDebug(("*--- Found public folder {}"
						"for recipient {}".format(
						destination_folder.encode('utf-8'),
						recipient.encode('utf-8'))))
		return destination_folder

	def PreDelivery(self, session, addrbook, store, folder, message):

		props = message.GetProps([PR_RECEIVED_BY_EMAIL_ADDRESS_W], 0)
		if props[0].ulPropTag != PR_RECEIVED_BY_EMAIL_ADDRESS_W:
			self.logger.logError("!--- Not received by emailaddress")
			return MP_CONTINUE,

		recipient = props[0].Value.lower()
		if not recipient:
			self.logger.logError("!--- No recipient in props {}".format(props))
			return MP_CONTINUE,

		recipfolder = self.publicfolder(recipient)
		if not recipfolder:
			self.logger.logDebug(("*--- No public folder for recipient {}"
				.format(recipient.encode('utf-8'))))
			return MP_CONTINUE,

		publicstore = GetPublicStore(session)
		if not publicstore:
			storeprops = store.GetProps([PR_MAILBOX_OWNER_ENTRYID], 0)
			if storeprops[0].ulPropTag == PR_MAILBOX_OWNER_ENTRYID:
				user = addrbook.OpenEntry(storeprops[0].Value, None, 0)
				userprops = user.GetProps([PR_EC_COMPANY_NAME_W], 0)
				if userprops[0].ulPropTag == PR_EC_COMPANY_NAME_W:
					companyname = userprops[0].Value
				else:
					companyname = None

				if not companyname:
					self.logger.logError(("!--- Cannot open a public store."
						' Use "kopano-storeadm -P"'
						" to create one if it is missing."))
					return MP_CONTINUE,

				ema = store.QueryInterface(IID_IExchangeManageStore)
				publicstoreid = ema.CreateStoreEntryID(None, companyname, MAPI_UNICODE)
				publicstore = session.OpenMsgStore(0, publicstoreid, None, MDB_WRITE)

		publicfolders = publicstore.OpenEntry(
			publicstore.GetProps([PR_IPM_PUBLIC_FOLDERS_ENTRYID], 0)[0].Value,
			None, MAPI_MODIFY)

		folderlist = recipfolder.split('/')
		folder = publicfolders
		for foldername in folderlist:
			if len(foldername) > 0:
				if hexversion >= 0x03000000:
					folder = folder.CreateFolder(0, foldername,
						"Create by Move to Public plugin", None,
						OPEN_IF_EXISTS | MAPI_UNICODE)
				else:
					folder = folder.CreateFolder(0, foldername,
						"Create by Move to Public plugin", None, OPEN_IF_EXISTS)

		msgnew = folder.CreateMessage(None, 0)
		tags = message.GetPropList(MAPI_UNICODE)
		message.CopyProps(tags, 0, None, IID_IMessage, msgnew, 0)

		msgnew.SaveChanges(0)
		folderid = folder.GetProps([PR_ENTRYID], 0)[0].Value
		msgid = msgnew.GetProps([PR_ENTRYID], 0)[0].Value

		publicstore.NotifyNewMail(NEWMAIL_NOTIFICATION(msgid, folderid, 0, None, 0))

		self.logger.logInfo(("*--- Message moved to public folder {}"
			.format(recipfolder)))

		return MP_STOP_SUCCESS,
