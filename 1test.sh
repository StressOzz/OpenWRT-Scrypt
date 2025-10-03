
#!/bin/sh
unset latest_version_on_github
unset current_version_on_router
main()
{
find_out_what_os_we_work_in
find_out_what_version_is_here
find_out_what_version_is_on_github
if [ "$(compare_version)" -eq 1 ]
   then
       update_zapret
   else
       dont_update_zapret
fi
}

function compare_version()
{
echo $latest_version_on_github $current_version_on_router | awk '
{
	split($1,version_on_github,".")
	split($2,version_here,".")

	version_on_github_major = version_on_github[1]
	version_here_major = version_here[1]

	if ( length(version_on_github[2]) == 0 )
		version_on_github_minor = "0"
	else
		version_on_github_minor = version_on_github[2]

	if ( length(version_here[2]) == 0 )
		version_here_minor = "0"
	else
		version_here_minor = version_here[2]

#	print("major github = " version_on_github_major)
#	print("minor github = " version_on_github_minor)
#	print("major router = " version_here_major)
#	print("minor router = " version_here_minor)

	if  ( version_on_github_major > version_here_major )
		print "1"
	else if	( version_on_github_minor > version_here_minor )
		print "1"
	else
		print "0"
}
'
}

function dont_update_zapret()
{
echo "zapret is fresh enough"
}

function find_out_what_version_is_on_github()
{
latest_version_on_github=$(curl -s https://api.github.com/repos/bol-van/zapret/releases/latest | awk '
BEGIN {
    FS = "\""
}

$0 ~ /tag_name/ {
    gsub("v","")
    print $4
}

')
}

function find_out_what_version_is_here()
{
current_version_on_router=$(/opt/zapret/nfq/nfqws | awk '
$0 ~ /version/ {
    gsub("v","")
    print $3
    exit
}
')
}

function find_out_what_os_we_work_in()
{
os_id=$(awk 'BEGIN {FS = "="} /^ID=/ {gsub("\"",""); print $2}' /etc/os-release)
}

function update_zapret()
{
case $os_id in
        almalinux|rocky|rhel|fedora|nobara|Deepin|debian|ubuntu|zorin|linuxmint)
        pc_download_and_install_freshest_zapret
        ;;
        openwrt)
        openwrt_download_and_install_freshest_zapret
        ;;
        manjaro)
        echo "манжара это кал https://telegra.ph/Manjaro-09-17 я пытался установить манжару в виртуалку чтобы потестировать этот скрипт но манжаровский пакетный менеджер даже в виртуалке чем-то попортил систему и после перезагрузки она не загрузилась. похоже её даже собственные мейнтейнеры не тестируют."
	exit 1
        ;;
        *)
        echo "похоже у вас какой-то обскурный дистр. если так то вы большой любитель пердолиться. перепишите этот скрипт под свой пакетный менеджер или sysvinit или что у вас там."
        exit 1
        ;;
esac
}



function debug_whats_in_variables()
{
echo $latest_version_on_github
echo $current_version_on_router
}

function openwrt_download_and_install_freshest_zapret()
{
service zapret stop
mkdir -p /opt/zapret
cd /opt
#wget $(curl -s https://api.github.com/repos/bol-van/zapret/releases/latest  | jq -r '.assets[] | select(.name | contains ("openwrt")) | .browser_download_url') -O /opt/zapret-latest.tar.gz
wget $(get_zapret_package_url_for_openwrt) -O /opt/zapret-latest.tar.gz
tar -xvzf /opt/zapret-latest.tar.gz
rm -v /opt/zapret-latest.tar.gz
cp -vr /opt/zapret-v*/* /opt/zapret/
rm -rfv zapret-v*
service zapret restart
}

function pc_download_and_install_freshest_zapret()
{
sudo systemctl stop zapret
sudo mkdir -p /opt/zapret
cd /opt
#sudo wget $(curl -s https://api.github.com/repos/bol-van/zapret/releases/latest  | jq -r '.assets[]  | .browser_download_url' | grep zapret-v[0-9\.]*.tar.gz | head -n 1) -O /opt/zapret-latest.tar.gz
sudo wget $(get_zapret_package_url_for_pc_linux) -O /opt/zapret-latest.tar.gz
sudo tar -xvzf /opt/zapret-latest.tar.gz
sudo rm -v /opt/zapret-latest.tar.gz
sudo cp -vr /opt/zapret-v*/* /opt/zapret/
sudo rm -rfv zapret-v*
sudo systemctl restart zapret
}

function get_zapret_package_url_for_pc_linux()
{
curl -s https://api.github.com/repos/bol-van/zapret/releases/latest | awk '
BEGIN {
    FS = "\""
}

$0 !~ /openwrt/ && /tar.gz/ && /browser/ {
    print $4
}'
}

function get_zapret_package_url_for_openwrt()
{
curl -s https://api.github.com/repos/bol-van/zapret/releases/latest | awk '
BEGIN {
    FS = "\""
}

$0 ~ /openwrt/ && /tar.gz/ && /browser/ {
    print $4
}'
}

#debug_whats_in_variables


main "$@"
