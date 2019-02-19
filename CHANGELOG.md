# v1.1.1
- Make sure the .env settings are honored also for MYSQL

# v1.1.0

- Reversed tag naming scheme. now `full-8.7.80-3.5.2` instead of ~~8.7.80-3.5.2-full~~
- Demo based on `docker-compose.yml` and `Makefile` files
- Check and fix file attributes in the `/var/lib/kopano/attachments` directory

# v1.0.0

- Groupware server [Kopano WebApp](https://kopano.io/)
- ActiveSync server [Z-Push](http://z-push.org/)
- Multi-staged build providing the images `full`, `debugtools` and `core`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script `conf` helping configuring Kopano components, WebApp and Z-Push
- Health check
- Hook for theming

