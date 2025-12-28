PORTNAME=	virt-tk-manager
PORTVERSION=	0.2.0
CATEGORIES=	emulators
MASTER_SITES=	
DISTFILES=	
MAINTAINER=	maintainers@example.test
COMMENT=	Tcl/Tk multi-backend virtualization manager
LICENSE=	MIT

RUN_DEPENDS=	tcl86:lang/tcl86 \
		tk86:x11-toolkits/tk86 \
		tcllib:devel/tcllib \
		tcltls:devel/tcltls \
		ssh:security/openssh-portable

NO_BUILD=	yes
NO_ARCH=	yes

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/share/virt-tk-manager
	cd ${WRKSRC} && ${CP} -R src ${STAGEDIR}${PREFIX}/share/virt-tk-manager/
	${INSTALL_SCRIPT} ${WRKSRC}/qemu_gui.tcl ${STAGEDIR}${PREFIX}/bin/virt-tk-manager

.include <bsd.port.mk>
