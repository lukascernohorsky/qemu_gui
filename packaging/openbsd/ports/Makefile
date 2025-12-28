COMMENT =	Tcl/Tk multi-backend virtualization manager

V =	0.2.0
DISTNAME =	virt-tk-manager-${V}
CATEGORIES =	emulators
HOMEPAGE =	https://example.test/virt-tk-manager
MAINTAINER =	maintainers@example.test
# MIT
PERMIT_PACKAGE =	Yes

RUN_DEPENDS =	lang/tcl/8.6 \
		x11/tk/8.6 \
		devel/tcllib \
		security/tcltls \
		security/openssh

NO_BUILD =	Yes
NO_TEST =	Yes

do-install:
	${INSTALL_DATA_DIR} ${PREFIX}/share/virt-tk-manager
	cp -R ${WRKSRC}/src ${PREFIX}/share/virt-tk-manager/
	${INSTALL_SCRIPT} ${WRKSRC}/qemu_gui.tcl ${PREFIX}/bin/virt-tk-manager

.include <bsd.port.mk>
