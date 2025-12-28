EAPI=8

DESCRIPTION="Tcl/Tk multi-backend virtualization manager"
HOMEPAGE="https://example.test/virt-tk-manager"
SRC_URI=""
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""
RDEPEND="dev-lang/tcl:0/8.6 dev-lang/tk dev-tcltk/tcllib dev-tcltk/tcltls net-misc/openssh"
DEPEND="${RDEPEND}"

src_install() {
	dodir /usr/share/virt-tk-manager
	cp -r src "${D}/usr/share/virt-tk-manager/" || die
	dobin qemu_gui.tcl
}
