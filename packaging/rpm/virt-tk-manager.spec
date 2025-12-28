Name:           virt-tk-manager
Version:        0.2.0
Release:        1%{?dist}
Summary:        Tcl/Tk multi-backend virtualization manager
License:        MIT
URL:            https://example.test/virt-tk-manager
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
Requires:       tcl >= 8.6, tk, tcllib, tcltls, openssh-clients

%description
virt-tk-manager provides a ttk-based GUI inspired by virt-manager, with a
plugin architecture for multiple hypervisors and a deterministic mock backend.

%prep
%setup -q

%build
# no build needed

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/virt-tk-manager
cp -a src %{buildroot}%{_datadir}/virt-tk-manager/
cp qemu_gui.tcl %{buildroot}%{_bindir}/virt-tk-manager

%files
%{_bindir}/virt-tk-manager
%{_datadir}/virt-tk-manager/src

%changelog
* Wed Jul 10 2024 virt-tk-manager team <maintainers@example.test> - 0.2.0-1
- Initial package
