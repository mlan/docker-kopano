# Road map

## kopano_spamd

[discussion](https://jira.kopano.io/browse/KC-666)

- let kopano-spamd create /var/lib/kopano/spamd/{ham,spam} with perm 770, user kopano, group amavis/spamassassin
- instead of invoking sa-learn, kopano-spamd should just write to ham  or spam folder depending on what happens (move to spam, spam, move from  spam, ham)
- create a simple python script that will use inotify on the ham and  spam directory. Whenever a new file appear then run sa-learn --spam/–ham  and delete the file on success.

So let the Kopano and postfix containers share the `var/lib/kopano/spamd` folder and run the cron job in the postfix container.

## Revisit Persistent Data

Consider consolidating directories which are candidates for persistence under `/srv`.

## /etc/entrypoint.d

Split up initialization functions and process supervision. Process supervision stays in entrypoint.sh, whereas the initialization functions are moved to individual files in /etc/entrypoint.d.

##Improve Health Check?

Verify the user anonymously.
```bash
ldapsearch -h dockerhost -xLLL -b dc=example,dc=com '(kopanoAccount=1)'
```

Check if kopano can get the user from LDAP
```bash
kopano-admin -l
```
check that apache and mysql is running
```bash
apache2ctl status
mysqlcheck -A
```
