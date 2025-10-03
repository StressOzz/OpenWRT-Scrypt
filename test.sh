#!/bin/sh
# как этот скрипт будет работать:
# у вас уже должен быть настроенный свежий запрет
# там уже должен быть хотя бы раз настроен обход блокировок ютуба
# это значит что в конфиге должна быть строка вида --filter-tcp=443 РАБОЧАЯ_СТРАТЕГИЯ --hostlist=/opt/zapret/lists/yt.txt --new
# файл /opt/zapret/lists/yt.txt это файл в котором перечислены домены ютуба то есть youtube.com и googlevideo.com
# скрипт автоматизирует поиск новой стратегии в случае если ютуб уже настроен и если вы сунете файл скрипта в кронтаб
# но можно его и руками запускать чтобы не делать всё руками
mkdir -p /opt/zapret/lists
printf "yt.be\nyoutu.be\ngooglevideo.com\nyoutube.com\ni.ytimg.com\nytimg.com" | tee /opt/zapret/lists/yt.txt


main()
{
uznaem_na_kakoi_sisteme_rabotaem
poluchaem_adres_google_global_cache_servera_i_prisvaivaem_v_peremennuyu
vykluchaem_zapret
pishem_vyvod_blockchecka_v_file_blockcheck_output
ischem_v_blockcheck_output_stroku_so_strategiei_obhoda_i_prisvaivaem_v_peremennuyu
suem_stroku_s_rabochei_strategiei_v_config_zapreta
vkluchaem_zapret
}

function uznaem_na_kakoi_sisteme_rabotaem()
{
os_id=$(awk 'BEGIN {FS = "="} /^ID=/ {gsub("\"",""); print $2}' /etc/os-release)
}

function delaem_backup_configa_zapreta()
{
cp -v /opt/zapret/config /opt/zapret/config_"$(date +%s)"
}

function suem_stroku_s_rabochei_strategiei_v_config_zapreta()
{
delaem_backup_configa_zapreta
#выравниваем конфиг чтобы каждая стратегия была новой строкой
sed -i -e 's/--new /--new\n/g' /opt/zapret/config
#вставляем рабочую стратегию между --filter-tcp=443 и --hostlist=/opt/zapret/lists/yt.txt
awk -v rabochaya_strategiya_awk="$rabochaya_strategiya" '$0 !~ /yt.txt/ { print } /yt.txt/ { print $1 " " rabochaya_strategiya_awk " " $(NF-1) " " $NF }' /opt/zapret/config > /opt/zapret/config_temp
cp -rfv /opt/zapret/config_temp /opt/zapret/config
}

function ischem_v_blockcheck_output_stroku_so_strategiei_obhoda_i_prisvaivaem_v_peremennuyu()
{
unset rabochaya_strategiya
rabochaya_strategiya=$(awk '/SUMMARY/{getline; print}' /tmp/test/blockcheck_output.txt | awk 'NR==1{for (i=6; i<=NF; i++) print $i}' | awk -v RS= '{$1=$1}1')
echo $rabochaya_strategiya
}


function poluchaem_adres_google_global_cache_servera_i_prisvaivaem_v_peremennuyu()
{
unset GGC_ADDRESS
GGC_ADDRESS=$(curl -s "https://www.youtube.com/watch?v=eZD5z7MTvJY" | awk 'BEGIN {
    RS="\\/"
    i=0
}
$1 ~ /googlevideo.com/ {
    array[$i]=sprintf( $0 )
    i++
}
END {
    print array[$i]
}
')
echo "GGC -> $GGC_ADDRESS"
}

function vykluchaem_zapret()
{
case $os_id in
		Deepin|debian|ubuntu|zorin|linuxmint|manjaro|almalinux|rocky|rhel|fedora|nobara)
		systemctl stop zapret
		;;
		openwrt)
		service zapret stop
		;;
		*)
		chto_to_ne_to_vyhodim
		;;
esac
}

function vkluchaem_zapret()
{
case $os_id in
		Deepin|debian|ubuntu|zorin|linuxmint|manjaro|almalinux|rocky|rhel|fedora|nobara)
		systemctl stop restart
		;;
		openwrt)
		service zapret restart
		;;
		*)
		chto_to_ne_to_vyhodim
		;;
esac
}

function chto_to_ne_to_vyhodim()
{
echo "похоже у вас какой-то обскурный дистр. если так то вы большой любитель пердолиться. перепишите этот скрипт под свой sysvinit/runit или что у вас там а то мне лень тестировать скрипт под все системы управления службами."

for i in {5..1..-1}
do
  printf "$i...\n"
  sleep 1
done

exit 1
}

function pishem_vyvod_blockchecka_v_file_blockcheck_output ()
{
vykluchaem_zapret
rm /tmp/blockcheck_output.txt
unset DOMAINS
rm -v /tmp/blockcheck_output.txt
DOMAINS=$GGC_ADDRESS \
IPVS=4 \
ENABLE_HTTP=0 \
ENABLE_HTTPS_TLS12=1 \
BATCH=1 \
ENABLE_HTTPS_TLS13=0 \
ENABLE_HTTP3=0 \
REPEATS=10 \
PARALLEL=1 \
SKIP_TPWS=1 \
SCANLEVEL=quick \
/opt/zapret/blockcheck.sh | tee /tmp/blockcheck_output.txt

}

main "$@"
