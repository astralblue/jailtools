SCRIPTS=	mkjail netjail setprognamedir
BINDIR?=	/root/bin
FILES=		create_freebsd_zroot.sh msg.sh jail.sh
FILESDIR?=	/root/bin
FILESDIR_jail.sh?= /etc
FILESMODE_jail.sh?= 755

.include <bsd.prog.mk>
