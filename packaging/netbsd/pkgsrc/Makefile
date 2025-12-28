# $NetBSD$

DISTNAME=	virt-tk-manager-0.2.0
CATEGORIES=	emulators
MASTER_SITES=	# empty, local distfile
MAINTAINER=	maintainers@example.test
HOMEPAGE=	https://example.test/virt-tk-manager
COMMENT=	Tcl/Tk virtualization manager with plugin backends
LICENSE=	mit

DEPENDS+=	tcl>=8.6:../../lang/tcl
DEPENDS+=	tk>=8.6:../../x11/tk
DEPENDS+=	tcllib>=1.20:../../devel/tcllib
DEPENDS+=	tcl-tls>=1.7:../../security/tcl-tls
DEPENDS+=	openssh-[0-9]*:../../security/openssh

NO_BUILD=	yes
WRKSRC=	${WRKDIR}/${DISTNAME}

INSTALLATION_DIRS+=	bin share/virt-tk-manager

do-install:
	cd ${WRKSRC} && ${CP} -R src ${DESTDIR}${PREFIX}/share/virt-tk-manager/
	${INSTALL_SCRIPT} ${WRKSRC}/qemu_gui.tcl ${DESTDIR}${PREFIX}/bin/virt-tk-manager

.include "../../mk/bsd.pkg.mk"
