"""
This code will query a LDAP/AD driectory server and updated the cgf file
/etc/kopano/movetopublic.cfg
/usr/share/kopano-dagent/python/plugins/movetopublic.cfg

export PYTHONPATH=/usr/share/kopano-dagent/python

"""
from zconfig import ZConfigParser
import configparser
import ldap

class KConfigParser(ZConfigParser):
	""" allow !directive in cfg files """
	def __init__(self, configfile, defaultconfig={}):
		self.config = configparser.ConfigParser(defaults=defaultconfig, \
			delimiters=('='), comment_prefixes=('#', '!'))
		self.readZConfig(configfile)

class ldapstores():
	defaultconfig = {
		'ldap_uri': None,
		'ldap_search_base': None,
		'ldap_bind_user': None,
		'ldap_bind_passwd': None,
		'ldap_user_unique_attribute': "uid",
		'ldap_user_search_filter': "(kopanoAccount=1)",
#		'ldap_user_search_filter': "(&(kopanoAccount=1)(kopanoResourceType=publicFolder:*))",
		'ldap_public_folder_attribute': "kopanoResourceType",
		'ldap_public_folder_attribute_token': "publicFolder"
	}

	def __init__(self, configfile = '/etc/kopano/ldap.cfg'):
		self.readconfig(configfile)

	def readconfig(self, configfile):
		config = KConfigParser(configfile, self.defaultconfig)
		options = [opt.split('_', 1)[1] for opt in self.defaultconfig.keys()]
		self.config = config.getdict('ldap',options)
		return self.config

	def searchquery(self):
		if (self.config['uri'] is None):
			print ("ldap_uri is None")
			sys.exit(0)
		else:
			l = ldap.initialize(self.config['uri'])
			try:
				l.protocol_version = ldap.VERSION3
				l.simple_bind_s(self.config['bind_user'] or u'', \
					self.config['bind_passwd'] or u'')
			except ldap.INVALID_CREDENTIALS:
				sys.exit(0)
			except ldap.LDAPError as e:
				print (e)
				sys.exit(0)
			try:
				ldap_result_id = l.search(self.config['search_base'], \
					ldap.SCOPE_SUBTREE, self.config['user_search_filter'], \
					[self.config['user_unique_attribute'], \
					self.config['public_folder_attribute']])
				results = []
				while 1:
					result_type, result_data = l.result(ldap_result_id, 0)
					if (result_data == []):
						break
					else:
						if result_type == ldap.RES_SEARCH_ENTRY:
							results.append(result_data[0])
			except ldap.LDAPError as e:
				print (e)
			l.unbind_s()
		return results

	def findpublic(self):
		stores = self.searchquery()
		public = []
		for store in stores:
			recipient = store[1].get(self.config['user_unique_attribute'])
			tokenandfolder = store[1].get(self.config['ldap_public_folder_attribute'])
			if tokenandfolder:
				token = tokenandfolder.split(':')[0]
				destination_folder = tokenandfolder.split(':')[1]
				if (token == self.config['ldap_public_folder_attribute_token']);
					public[recipient] = destination_folder
		return public

	def printpublic(self, outputfile = '/etc/kopano/movetopublic.cfg'):
		public = self.findpublic()
		i = 1
		for recipient in public.keys():
			print ("rule%d_recipient = %s", i, recipient)
			print ("rule%d_destination_folder = %s", i, public[recipient])
			i += 1

s = ldapstores()
s.printpublic()
