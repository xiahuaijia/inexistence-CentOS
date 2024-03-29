#!/bin/bash
#
# https://github.com/xiahuaijia/inexistence-CentOS
# Author: Aniverse
#
# bash <(curl -s https://raw.githubusercontent.com/xiahuaijia/inexistence-CentOS/master/inexistence.sh)
# bash -c "$(wget -qO- https://github.com/xiahuaijia/inexistence-CentOS/raw/master/inexistence.sh)"
#
# PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# export PATH
# --------------------------------------------------------------------------------
DISABLE=0
DeBUG=0
INEXISTENCEVER=1.0.0
INEXISTENCEDATE=2021.01.23
# --------------------------------------------------------------------------------

# 获取参数

OPTS=$(getopt -n "$0" -o dsyu:p: --long "yes,tr-skip,skip,debug,apt-yes,apt-no,swap-yes,swap-no,bbr-yes,bbr-no,flood-yes,flood-no,flexget-yes,flexget-no,rclone-yes,rclone-no,tweaks-yes,tweaks-no,mt-single,mt-double,mt-max,mt-half,user:,password:,webpass:,de:,delt:,qb:,rt:,tr:,lt:" -- "$@")

eval set -- "$OPTS"

while true; do
  case "$1" in
    -u | --user     ) ANUSER="$2"       ; shift ; shift ;;
    -p | --password ) ANPASS="$2"       ; shift ; shift ;;

    --qb            ) { if [[ $2 == repo ]]; then qb_version='Install from repo'   ; else qb_version=$2   ; fi ; } ; shift ; shift ;;
    --tr            ) { if [[ $2 == repo ]]; then tr_version='Install from repo'   ; else tr_version=$2   ; fi ; } ; shift ; shift ;;
    --de            ) { if [[ $2 == repo ]]; then de_version='Install from repo'   ; else de_version=$2   ; fi ; } ; shift ; shift ;;
    --rt            ) rt_version=$2 ; shift ; shift ;;
    --lt            ) lt_version=$2 ; shift ; shift ;;

    -d | --debug    ) DeBUG=1           ; shift ;;
    -y | --yes      ) ForceYes=1        ; shift ;;

    --tr-skip       ) TRdefault="No"    ; shift ;;
    --apt-yes       ) aptsources="Yes"  ; shift ;;
    --apt-no        ) aptsources="No"   ; shift ;;
    --swap-yes      ) USESWAP="Yes"     ; shift ;;
    --swap-no       ) USESWAP="No"      ; shift ;;
    --bbr-yes       ) InsBBR="Yes"      ; shift ;;
    --bbr-no        ) InsBBR="No"       ; shift ;;
    --flood-yes     ) InsFlood="Yes"    ; shift ;;
    --flood-no      ) InsFlood="No"     ; shift ;;
    --flexget-yes   ) InsFlex="Yes"     ; shift ;;
    --flexget-no    ) InsFlex="No"      ; shift ;;
    --rclone-yes    ) InsRclone="Yes"   ; shift ;;
    --rclone-no     ) InsRclone="No"    ; shift ;;
    --tweaks-yes    ) UseTweaks="Yes"   ; shift ;;
    --tweaks-no     ) UseTweaks="No"    ; shift ;;
    --mt-single     ) MAXCPUS=1         ; shift ;;
    --mt-double     ) MAXCPUS=2         ; shift ;;
    --mt-max        ) MAXCPUS=$(nproc)  ; shift ;;
    --mt-half       ) MAXCPUS=$(echo "$(nproc) / 2"|bc)  ; shift ;;

    -- ) shift; break ;;
     * ) break ;;
  esac
done

if [[ $DeBUG == 1 ]]; then
    ANUSER=aniverse ; aptsources=No ; MAXCPUS=$(nproc)
fi
# --------------------------------------------------------------------------------
export OutputLOG=`pwd`/install.txt 
touch $OutputLOG
export Installation_status_prefix=inexistence-CentOS
rm -f /tmp/$Installation_status_prefix.*.1.lock /tmp/$Installation_status_prefix.*.2.lock
export SCLocation=/etc/inexistence/01.Log/SourceCodes
export LOCKLocation=/etc/inexistence/01.Log/Lock
# --------------------------------------------------------------------------------
### 颜色样式 ###
function _colors() {
black=$(tput setaf 0); red=$(tput setaf 1); green=$(tput setaf 2); yellow=$(tput setaf 3);
blue=$(tput setaf 4); magenta=$(tput setaf 5); cyan=$(tput setaf 6); white=$(tput setaf 7);
on_red=$(tput setab 1); on_green=$(tput setab 2); on_yellow=$(tput setab 3); on_blue=$(tput setab 4);
on_magenta=$(tput setab 5); on_cyan=$(tput setab 6); on_white=$(tput setab 7); bold=$(tput bold);
dim=$(tput dim); underline=$(tput smul); reset_underline=$(tput rmul); standout=$(tput smso);
reset_standout=$(tput rmso); normal=$(tput sgr0); alert=${white}${on_red}; title=${standout};
baihuangse=${white}${on_yellow}; bailanse=${white}${on_blue}; bailvse=${white}${on_green};
baiqingse=${white}${on_cyan}; baihongse=${white}${on_red}; baizise=${white}${on_magenta};
heibaise=${black}${on_white}; heihuangse=${on_yellow}${black}
jiacu=${normal}${bold}; shanshuo=$(tput blink); wuguangbiao=$(tput civis); guangbiao=$(tput cnorm)
CW="${bold}${baihongse} ERROR ${jiacu}";ZY="${baihongse}${bold} ATTENTION ${jiacu}";JG="${baihongse}${bold} WARNING ${jiacu}" ; }
_colors
# --------------------------------------------------------------------------------
# 增加 swap
function _use_swap() { 
    dd if=/dev/zero of=/root/.swapfile bs=1MiB count=2048 >> $OutputLOG 2>&1
    chmod 600 /root/.swapfile
    mkswap /root/.swapfile >> $OutputLOG 2>&1
    swapon /root/.swapfile >> $OutputLOG 2>&1
    if [[ ` swapon -s | grep -c /root/.swapfile ` == 1 ]]; then
    touch /tmp/$Installation_status_prefix.SwapON.1.lock
    else
    touch /tmp/$Installation_status_prefix.SwapON.2.lock 
    fi
}

# 关掉之前开的 swap
function _disable_swap() { swapoff /root/.swapfile  ;  rm -f /root/.swapfile ; }

# 用于退出脚本
export TOP_PID=$$
trap 'exit 1' TERM

# 判断是否在运行
function _if_running () { ps -ef | grep "$1" | grep -v grep > /dev/null && echo "${green}Running ${normal}" || echo "${red}Inactive${normal}" ; }

### 硬盘计算 ###
calc_disk() {
local total_size=0 ; local array=$@
for size in ${array[@]} ; do
    [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
    [ "`echo ${size:(-1)}`" == "K" ] && size=0
    [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
    [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
    [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
    total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
done ; echo ${total_size} ; }


### 操作系统检测 ###
get_opsy() { [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
[ -f /etc/os-release  ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
[ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return ; }

# --------------------------------------------------------------------------------
### 是否为 IPv4 地址(其实也不一定是) ###
function isValidIpAddress() { echo $1 | grep -qE '^[0-9][0-9]?[0-9]?\.[0-9][0-9]?[0-9]?\.[0-9][0-9]?[0-9]?\.[0-9][0-9]?[0-9]?$' ; }

### 是否为内网 IPv4 地址 ###
function isInternalIpAddress() { echo $1 | grep -qE '(192\.168\.((\d{1,2})|(1\d{2})|(2[0-4]\d)|(25[0-5]))\.((\d{1,2})$|(1\d{2})$|(2[0-4]\d)$|(25[0-5])$))|(172\.((1[6-9])|(2\d)|(3[0-1]))\.((\d{1,2})|(1\d{2})|(2[0-4]\d)|(25[0-5]))\.((\d{1,2})$|(1\d{2})$|(2[0-4]\d)$|(25[0-5])$))|(10\.((\d{1,2})|(1\d{2})|(2[0-4]\d)|(25[0-5]))\.((\d{1,2})|(1\d{2})|(2[0-4]\d)|(25[0-5]))\.((\d{1,2})$|(1\d{2})$|(2[0-4]\d)$|(25[0-5])$))' ; }

# --------------------------------------------------------------------------------
# 检查客户端是否已安装、客户端版本
function _check_install_1(){
client_location=$( command -v ${client_name} )

[[ "${client_name}" == "qbittorrent-nox" ]] && client_name=qb
[[ "${client_name}" == "transmission-daemon" ]] && client_name=tr
[[ "${client_name}" == "deluged" ]] && client_name=de
[[ "${client_name}" == "rtorrent" ]] && client_name=rt
[[ "${client_name}" == "flexget" ]] && client_name=flex

if [[ -a $client_location ]]; then
    eval "${client_name}"_installed=Yes
else
    eval "${client_name}"_installed=No
fi ; }

function version_ge(){ test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1" ; }

function _check_install_2(){
for apps in qbittorrent-nox deluged rtorrent transmission-daemon flexget rclone irssi; do
    client_name=$apps ; _check_install_1
done ; }

function _client_version_check(){
  [[ $qb_installed == Yes ]] && qbtnox_ver=$( qbittorrent-nox --version 2>&1 | awk '{print $2}' | sed "s/v//" )
  [[ $de_installed == Yes ]] && deluged_ver=$( deluged --version 2>&1 | grep deluged | awk '{print $2}' ) && delugelt_ver=$( deluged --version 2>&1 | grep libtorrent | grep -Eo "[01].[0-9]+.[0-9]+" )
  [[ $rt_installed == Yes ]] && rtorrent_ver=$( rtorrent -h 2>&1 | head -n1 | sed -ne 's/[^0-9]*\([0-9]*\.[0-9]*\.[0-9]*\)[^0-9]*/\1/p' )
  [[ $tr_installed == Yes ]] && trd_ver=$( transmission-daemon --help 2>&1 | head -n1 | awk '{print $2}' )
  find /usr/lib -name "libtorrent-rasterbar*" 2>/dev/null | grep -q libtorrent-rasterbar && lt_exist=yes
  [[ $lt_exist == Yes ]] && lt_ver=$( python -c "import libtorrent; print libtorrent.version" | grep -Eo "[012]\.[0-9]+\.[0-9]+" )
  lt_ver_qb3_ok=No ; [[ ! -z $lt_ver ]] && version_ge $lt_ver 1.0.6 && lt_ver_qb3_ok=Yes
  lt_ver_de2_ok=No ; [[ ! -z $lt_ver ]] && version_ge $lt_ver 1.1.3 && lt_ver_de2_ok=Yes ; }

# --------------------------------------------------------------------------------
### 随机数 ###
function _string() { perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15 ; }
# --------------------------------------------------------------------------------

#禁用SELinux
function _Disable_SELinux() {
sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
setenforce 0
echo -e "Disable SELinux ... ${green}${bold}DONE${normal}"
}

# 安装基础软件 最小化安装
function pre_install() {
echo -e "${bold}Checking your server's Software ...Take a few seconds${normal}"
# 装 ifconfig 以防万一（最小化安装没有这个工具……）
#if [[ ! -n `command -v ifconfig` ]]; then echo "${bold}Now the script is installing ${yellow}ifconfig${jiacu} ...${normal}" ; yum install -y net-tools  ; fi
#[[ ! $? -eq 0 ]] && echo -e "${red}${bold}Failed to install net-tools, please check it and rerun once it is resolved${normal}\n" && kill -s TERM $TOP_PID

yum install -y -q epel-release net-tools wget >> $OutputLOG 2>&1

#安装deluge 系统源
rpm -i --quiet http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm >> $OutputLOG 2>&1

#安装BBR内核 系统源
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org >> $OutputLOG 2>&1
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm >> $OutputLOG 2>&1
}

# 安装基础软件 最小化安装
function _env_install() {
yum install -y screen git curl jq python-devel libffi-devel python-setuptools ncurses-devel m2crypto iperf iperf3 htop nload vim python-pip dstat ethtool smartmontools tree zip unzip ntp >> $OutputLOG 2>&1

pip install --upgrade pip setuptools >> $OutputLOG 2>&1

systemctl stop postfix >> $OutputLOG 2>&1
systemctl disable postfix >> $OutputLOG 2>&1
systemctl stop firewalld >> $OutputLOG 2>&1
systemctl disable firewalld >> $OutputLOG 2>&1

touch /tmp/$Installation_status_prefix.env_install.1.lock
}


### 输入自己想要的软件版本 ###
# ${blue}(use it at your own risk)${normal}
function _input_version() {
echo -e "\n${JG} ${bold}Use it at your own risk and make sure to input version correctly${normal}"
read -ep "${bold}${yellow}Input the version you want: ${cyan}" input_version_num; echo -n "${normal}"
}

function _input_version_lt() {
echo -e "\n${baihongse}${bold} ATTENTION ${normal} ${bold}Make sure to input the correct version${normal}"
echo -e "${red}${bold} Here is a list of all the available versions${normal}\n"
# wget -qO- "https://github.com/arvidn/libtorrent" | grep "data-name" | cut -d '"' -f2 | pr -3 -t ; echo
rm -f $HOME/lt.git.tag
git ls-remote --tags  https://github.com/arvidn/libtorrent | awk -F'[/]' '{print $3}' >  $HOME/lt.git.tag
git ls-remote --heads https://github.com/arvidn/libtorrent | awk -F'[/]' '{print $3}' >> $HOME/lt.git.tag
cat $HOME/lt.git.tag | pr -3 -t
rm -f $HOME/lt.git.tag
read -ep "${bold}${yellow}Input the version you want: ${cyan}" input_version_num; echo -n "${normal}" ; }

### 检查系统是否被支持 ###
function _oscheck() {
if [[ ! "$SysSupport" == 1 ]]; then
echo -e "\n${bold}${red} Only Centos 7 is supported by this script${normal}\n"
exit 1
fi ; }

function _check_status() {
[[   -f /tmp/$Installation_status_prefix.$1.1.lock ]] && echo -e " ${green}${bold}DONE${normal}"
[[   -f /tmp/$Installation_status_prefix.$1.2.lock ]] && echo -e " ${red}${bold}FAILED${normal}"
[[ ! -f /tmp/$Installation_status_prefix.$1.1.lock ]] && [[ ! -f /tmp/$Installation_status_prefix.$1.2.lock ]] && echo -e " ${red}${bold}Unknown State${normal}"
}

# Ctrl+C 时恢复样式
cancel() { echo -e "${normal}" ; exit ; }
trap cancel SIGINT

# --------------------------------------------------------------------------------
lang_do_not_install="Do not install"
language_select_another_version="Select another version"
which_version_do_you_want="Which version do you want?"
lang_yizhuang="You have already installed"
lang_will_be_installed="will be installed"
lang_note_that="Note that"
lang_would_you_like_to_install="Would you like to install"


# --------------------- 系统检查 --------------------- #
function _intro() {

 [[ $DeBUG != 1 ]] && clear 

# 检查是否以 root 权限运行脚本
if [[ ! $DeBUG == 1 ]]; then if [[ $EUID != 0 ]]; then echo -e "\n${title}${bold}Navie! I think this young man will not be able to run this script without root privileges.${normal}\n" ; exit 1
else echo -e "\n${green}${bold}Excited! You're running this script as root. Let's make some big news ... ${normal}" ; fi ; fi

arch=$( uname -m ) # 架构，可以识别 ARM
lbit=$( getconf LONG_BIT ) # 只显示多少位，无法识别 ARM

# 检查是否为 x86_64 架构
[[ ! $arch == x86_64 ]] && { echo -e "${title}${bold}Too simple! Only x86_64 is supported${normal}" ; exit 1 ; }

# 检查系统版本；如果是 Ubuntu 或 Debian 的就禁止运行，反正不支持……
SysSupport=0
DISTRO=`  awk -F'[= "]' '/PRETTY_NAME/{print $3}' /etc/os-release  `
DISTROL=`  echo $DISTRO | tr 'A-Z' 'a-z'  `
CODENAME=`  cat /etc/os-release | grep VERSION= | tr '[A-Z]' '[a-z]' | sed 's/\"\|(\|)\|[0-9.,]\|version\|lts//g' | awk '{print $2}'  `
OSVERSION=` cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/' `
[[ $DISTRO == Ubuntu ]] && osversion=`  grep Ubuntu /etc/issue | head -1 | grep -oE  "[0-9.]+"  `
[[ $DISTRO == Debian ]] && osversion=`  cat /etc/debian_version  `
[[ $DISTROL != centos ]] && SysSupport=2 &&echo -e "\n${red}${bold}Navie! Your system version is ${DISTRO} ${osversion} , Shell script only supports CentOS 7. ${normal}\n"
[[ $DISTROL != centos ]] && [[ $OSVERSION != 7 ]] && SysSupport=3 && echo -e "\n${red}${bold}Navie! Your system version is ${DISTRO} ${OSVERSION} , Shell script only supports CentOS 7. ${normal}\n" 
[[ $DISTROL == centos ]] && [[ $OSVERSION == 7 ]] && SysSupport=1
[[ $DeBUG == 1 ]] && echo "${bold}DISTRO=$DISTRO, CODENAME=$CODENAME, osversion=$osversion, OSVERSION=${OSVERSION}, SysSupport=$SysSupport${normal}"

# 检查本脚本是否支持当前系统
_oscheck

# 安装基础工具
pre_install

  echo -e "${bold}Checking your server's public IPv4 address ...${normal}"
# serveripv4=$( ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' )
# serveripv4=$( ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:" )
  serveripv4=$( ip route get 8.8.8.8 | awk '{print $3}' )
  isInternalIpAddress "$serveripv4" || serveripv4=$( wget -t1 -T6 -qO- v4.ipv6-test.com/api/myip.php )
  isValidIpAddress "$serveripv4" || serveripv4=$( wget -t1 -T6 -qO- checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//' )
  isValidIpAddress "$serveripv4" || serveripv4=$( wget -t1 -T7 -qO- ipecho.net/plain )
  isValidIpAddress "$serveripv4" || { echo "${bold}${red}${shanshuo}ERROR ${jiacu}${underline}Failed to detect your public IPv4 address, use internal address instead${normal}" ; serveripv4=$( ip route get 8.8.8.8 | awk '{print $3}' ) ; }

  wget -t1 -T6 -qO- https://ipapi.co/json >~/ipapi 2>&1
  ccoodde=$( cat ~/ipapi | grep \"country\"      | awk -F '"' '{print $4}' ) 2>/dev/null
  country=$( cat ~/ipapi | grep \"country_name\" | awk -F '"' '{print $4}' ) 2>/dev/null
  regionn=$( cat ~/ipapi | grep \"region\"       | awk -F '"' '{print $4}' ) 2>/dev/null
  cityyyy=$( cat ~/ipapi | grep \"city\"         | awk -F '"' '{print $4}' ) 2>/dev/null
  isppppp=$( cat ~/ipapi | grep \"org\"          | awk -F '"' '{print $4}' ) 2>/dev/null
  asnnnnn=$( cat ~/ipapi | grep \"asn\"          | awk -F '"' '{print $4}' ) 2>/dev/null
  [[ $cityyyy == Singapore ]] && unset cityyyy
  [[ $isppppp == "" ]] && isp="No ISP detected"
  [[ $asnnnnn == "" ]] && isp="No ASN detected"
  rm -f ~/ipapi 2>&1

  echo "${bold}Checking your server's public IPv6 address ...${normal}"

  serveripv6=$( wget -t1 -T5 -qO- v6.ipv6-test.com/api/myip.php | grep -Eo "[0-9a-z:]+" | head -n1 )
# serveripv6=$( wget -qO- -t1 -T8 ipv6.icanhazip.com )

# 2018.10.10 重新启用对于网卡的判断。我忘了是出于什么原因我之前禁用了它？
[ -n "$(grep 'eth0:' /proc/net/dev)" ] && wangka=eth0 || wangka=`cat /proc/net/dev |awk -F: 'function trim(str){sub(/^[ \t]*/,"",str); sub(/[ \t]*$/,"",str); return str } NR>2 {print trim($1)}'  |grep -Ev '^lo|^sit|^stf|^gif|^dummy|^vmnet|^vir|^gre|^ipip|^ppp|^bond|^tun|^tap|^ip6gre|^ip6tnl|^teql|^venet|^he-ipv6|^docker' |awk 'NR==1 {print $0}'`
wangka=` ifconfig -a | grep -B 1 $(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}') | head -n1 | awk '{print $1}' | sed "s/:$//"  `
wangka=`  ip route get 8.8.8.8 | awk '{print $5}'  `
# serverlocalipv6=$( ip addr show dev $wangka | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' | grep -v fe80 | head -n1 )




  echo -e "${bold}Checking your server's specification ...${normal}"

  kern=$( uname -r )

# Virt-what
  wget -qO /usr/local/bin/virt-what https://github.com/xiahuaijia/inexistence-CentOS/raw/master/01.Files/app/virt-what
  mkdir -p /usr/lib/virt-what
  wget -qO /usr/lib/virt-what/virt-what-cpuid-helper https://github.com/xiahuaijia/inexistence-CentOS/raw/master/01.Files/app/virt-what-cpuid-helper
  chmod +x /usr/local/bin/virt-what /usr/lib/virt-what/virt-what-cpuid-helper
  virtua="$(virt-what)" 2>/dev/null

  cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
  cputhreads=$( grep 'processor' /proc/cpuinfo | sort -u | wc -l )
  cpucores_single=$( grep 'core id' /proc/cpuinfo | sort -u | wc -l )
  cpunumbers=$( grep 'physical id' /proc/cpuinfo | sort -u | wc -l )
  cpucores=$( expr $cpucores_single \* $cpunumbers )
  [[ $cpunumbers == 2 ]] && CPUNum='Dual ' ; [[ $cpunumbers == 4 ]] && CPUNum='Quad ' ; [[ $cpunumbers == 8 ]] && CPUNum='Octa '

  disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' ))
  disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' ))
  disk_total_size=$( calc_disk ${disk_size1[@]} )
  disk_used_size=$( calc_disk ${disk_size2[@]} )
  freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
  tram=$( free -m | awk '/Mem/ {print $2}' )
  uram=$( free -m | awk '/Mem/ {print $3}' )



  echo -e "${bold}Checking bittorrent clients' version ...${normal}"

  _check_install_2
  _client_version_check

  YUM_cache=` yum list qbittorrent-nox deluge transmission-daemon `

  QB_repo_ver=` echo $YUM_cache | grep -B1 qbittorrent-nox | grep -Eo "[234]\.[0-9.]+\.[0-9.]+" | head -n1 `
  QB_latest_ver=$( wget -qO- https://github.com/qbittorrent/qBittorrent/releases | grep releases/tag | grep -Eo "[45]\.[0-9.]+" | head -n1 )
  [[ -z $QB_latest_ver ]] && QB_latest_ver=4.1.5
  [[ $DeBUG == 1 ]] && echo "${bold}QB_repo_ver=${QB_repo_ver}, QB_latest_ver=${QB_latest_ver} ${normal}"

  DE_repo_ver=` echo $YUM_cache | grep -B1 deluge | grep -Eo "[12]\.[0-9.]+\.[0-9.]+" | head -n1 `
  DE_latest_ver=$( wget -qO- https://dev.deluge-torrent.org/wiki/ReleaseNotes | grep wiki/ReleaseNotes | grep -Eo "[12]\.[0-9.]+" | sed 's/">/ /' | awk '{print $1}' | head -n1 )
  [[ -z $DE_latest_ver ]] && DE_latest_ver=1.3.15
  [[ $DeBUG == 1 ]] && echo "${bold}DE_repo_ver=${DE_repo_ver}, DE_latest_ver=${DE_latest_ver} ${normal}"

# DE_github_latest_ver=` wget -qO- https://github.com/deluge-torrent/deluge/releases | grep releases/tag | grep -Eo "[12]\.[0-9.]+.*" | sed 's/\">//' | head -n1 `

  #TR_repo_ver=` yum list transmission-daemon* | grep -B1 transmission-daemon | grep -Eo "[23]\.[0-9.]+" | head -n1 `
  TR_repo_ver=` echo $YUM_cache | grep -Eo "transmission-daemon.x86_64 [23]\.[0-9]+" | grep -Eo "[23]\.[0-9.]+" `
  TR_latest_ver=$( wget -qO- https://github.com/transmission/transmission/releases | grep releases/tag | grep -Eo "[23]\.[0-9.]+" | head -n1 )
  [[ -z $TR_latest_ver ]] && TR_latest_ver=2.94
  [[ $DeBUG == 1 ]] && echo "${bold}TR_repo_ver=${TR_repo_ver}, TR_latest_ver=${TR_latest_ver} ${normal}"
  
  [[ $DeBUG != 1 ]] && clear 

  #wget -t1 -T5 -qO- https://raw.githubusercontent.com/Aniverse/inexistence/master/03.Files/inexistence.logo.1

  echo "${bold}---------- [System Information] ----------${normal}"
  echo

  echo -ne "  IPv4      : "
  if [[ "${serveripv4}" ]]; then
      echo "${cyan}$serveripv4${normal}"
  else
      echo "${cyan}No Public IPv4 Address Found${normal}"
  fi

  echo -ne "  IPv6      : "
  if [[ "${serveripv6}" ]]; then
      echo "${cyan}$serveripv6${normal}"
  else
      echo "${cyan}No IPv6 Address Found${normal}"
  fi

  echo -e  "  ASN & ISP : ${cyan}$asnnnnn, $isppppp${normal}"
  echo -ne "  Location  : ${cyan}"
  [[ ! $cityyyy == "" ]] && echo -ne "$cityyyy, "
  [[ ! $regionn == "" ]] && echo -ne "$regionn, "
  [[ ! $country == "" ]] && echo -ne "$country"
# [[ ! $ccoodde == "" ]] && echo -ne " / $ccoodde"
  echo -e  "${normal}"

  echo -e  "  CPU       : ${cyan}$CPUNum$cname${normal}"
  echo -e  "  Cores     : ${cyan}${freq} MHz, ${cpucores} Core(s), ${cputhreads} Thread(s)${normal}"
  echo -e  "  Mem       : ${cyan}$tram MB ($uram MB Used)${normal}"
  echo -e  "  Disk      : ${cyan}$disk_total_size GB ($disk_used_size GB Used)${normal}"
  echo -e  "  OS        : ${cyan}$DISTRO $OSVERSION ($arch) ${normal}"
  echo -e  "  Kernel    : ${cyan}$kern${normal}"
  echo -e  "  Script    : ${cyan}$INEXISTENCEDATE${normal}"

  echo -ne "  Virt      : "
  if [[ "${virtua}" ]]; then
      echo "${cyan}$virtua${normal}"
  else
      echo "${cyan}No Virtualization Detected${normal}"
  fi

echo
echo -e "${bold}For more information about this script, no way~"
echo -e "Press ${on_red}Ctrl+C${normal} ${bold}to exit${jiacu}, or press ${bailvse}ENTER${normal} ${bold}to continue" ; [[ ! $ForceYes == 1 ]] && read input

}

# --------------------- 录入账号密码部分 --------------------- #

# 向用户确认信息，Yes or No
function _confirmation(){
local answer
while true ; do
    read answer
    case $answer in [yY] | [yY]     ) return 0 ;;
                    [nN] | [nN]     ) return 1 ;;
                    *               ) echo "${bold}Please enter ${bold}${green}[Y]es${normal} or [${bold}${red}N${normal}]o";;
    esac
done ; }


# 生成随机密码，genln=密码长度
function genpasswd() { local genln=$1 ; [ -z "$genln" ] && genln=12 ; tr -dc A-Za-z0-9 < /dev/urandom | head -c ${genln} | xargs ; }


# 检查用户名的有效性，抄自：https://github.com/Azure/azure-devops-utils
function validate_username() {
  ANUSER="$1" ; local min=1 ; local max=32
  # This list is not meant to be exhaustive. It's only the list from here: https://docs.microsoft.com/azure/virtual-machines/linux/usernames
  local reserved_names=" adm admin audio backup bin cdrom crontab daemon dialout dip disk fax floppy fuse games gnats irc kmem landscape libuuid list lp mail man messagebus mlocate netdev news nobody nogroup operator plugdev proxy root sasl shadow src ssh sshd staff sudo sync sys syslog tape tty users utmp uucp video voice whoopsie www-data "
  if [ -z "$ANUSER" ]; then
      username_valid=empty
  elif [ ${#ANUSER} -lt $min ] || [ ${#username} -gt $max ]; then
      echo -e "${CW} The username must be between $min and $max characters${normal}"
      username_valid=false
  elif ! [[ "$ANUSER" =~ ^[a-z][-a-z0-9_]*$ ]]; then
      echo -e "${CW} The username must contain only lowercase letters, digits, underscores and starts with a letter${normal}"
      username_valid=false
  elif [[ "$reserved_names" =~ " $ANUSER " ]]; then
      echo -e "${CW} The username cannot be an Ubuntu reserved name${normal}"
      username_valid=false
  else
      username_valid=true
  fi
}


# 询问用户名
function _askusername(){ 
     [[ $DeBUG != 1 ]] && clear 

validate_username $ANUSER

if [[ $username_valid == empty ]]; then

    echo -e "${bold}${yellow}The script needs a username${jiacu}"
    echo -e "This will be your primary user. It can be an existing user or a new user ${normal}"
    _input_username

elif [[ $username_valid == false ]]; then

  # echo -e "${JG} The preset username doesn't pass username check, please set a new username"
    _input_username

elif [[ $username_valid == true ]]; then

  # ANUSER=`  echo $ANUSER | tr 'A-Z' 'a-z'  `
    echo -e "${bold}Username sets to ${blue}$ANUSER${normal}\n"

fi ; }



# 录入用户名
function _input_username(){

local answerusername ; local reinput_name
confirm_name=false

while [[ $confirm_name == false ]]; do

    while [[ $answerusername = "" ]] || [[ $reinput_name = true ]] || [[ $username_valid = false ]]; do
        reinput_name=false
        read -ep "${bold}Enter username: ${blue}" answerusername ; echo -n "${normal}"
        validate_username $answerusername
    done

    addname=$answerusername
    echo -n "${normal}${bold}Confirm that username is ${blue}${addname}${normal}, ${bold}${green}[Y]es${normal} or [${bold}${red}N${normal}]o? "

    read answer
    case $answer in [yY] | [yY][Ee][Ss] | "" ) confirm_name=true ;;
                    [nN] | [nN][Oo]          ) reinput_name=true ;;
                    *                        ) echo "${bold}Please enter ${bold}${green}[Y]es${normal} or [${bold}${red}N${normal}]o";;
    esac

    ANUSER=$addname

done ; echo ; }


# 一定程度上的密码复杂度检测：https://stackoverflow.com/questions/36524872/check-single-character-in-array-bash-for-password-generator
# 询问密码。目前的复杂度判断还不够 Flexget 的程度，但总比没有强……

function _askpassword() {

local password1 ; local password2 ; #local exitvalue=0
exec 3>&1 >/dev/tty

if [[ $ANPASS = "" ]]; then

    echo "${bold}${yellow}The script needs a password, it will be used for Unix and WebUI${jiacu} "
    echo "The password must consist of characters and numbers and at least 8 chars,"
    echo "or you can leave it blank to generate a random password"

    while [ -z $localpass ]; do

      # echo -n "${bold}Enter the password: ${blue}" ; read -e password1
        read -ep "${jiacu}Enter the password: ${blue}" password1 ; echo -n "${normal}"

        if [ -z $password1 ]; then

            localpass=$(genpasswd) ; # exitvalue=1
            echo "${jiacu}Random password sets to ${blue}$localpass${normal}"

        # At least [8] chars long
        elif [ ${#password1} -lt 8 ]; then

            echo "${bold}${red}ERROR${normal} ${bold}Password must be at least ${red}[8]${jiacu} chars long${normal}" && continue

        # At least [1] number
        elif ! echo "$password1" | grep -q '[0-9]'; then

            echo "${bold}${red}ERROR${normal} ${bold}Password must have at least ${red}[1] number${normal}" && continue

        # At least [1] letter
        elif ! echo "$password1" | grep -q '[a-zA-Z]'; then

            echo "${bold}${red}ERROR${normal} ${bold}Password must have at least ${red}[1] letter${normal}" && continue

        else

            while [[ $password2 = "" ]]; do
                read -ep "${jiacu}Enter the new password again: ${blue}" password2 ; echo -n "${normal}"
            done

            if [ $password1 != $password2 ]; then
                echo "${bold}${red}WARNING${normal} ${bold}Passwords do not match${normal}" ; unset password2
            else
                localpass=$password1
            fi

        fi

    done

    ANPASS=$localpass
    exec >&3- ; echo ; # return $exitvalue

else

    echo -e "${bold}Password sets to ${blue}$ANPASS${normal}\n"

fi ; }

# --------------------- 询问安装前是否需要更换软件源 --------------------- #

function _askaptsource() {

while [[ $aptsources = "" ]]; do

    read -ep "${bold}${yellow}Would you like to change sources list?${normal} [${cyan}Y${normal}]es or [N]o: " responce
  # echo -ne "${bold}${yellow}Would you like to change sources list?${normal} [${cyan}Y${normal}]es or [N]o: " ; read -e responce

    case $responce in
        [yY] | "" ) aptsources=Yes ;;
        [nN]      ) aptsources=No ;;
        *         ) aptsources=Yes ;;
    esac

done

if [[ $aptsources == Yes ]]; then
    echo "${bold}${baiqingse}/etc/apt/sources.list${normal} ${bold}will be replaced${normal}"
else
    echo "${baizise}/etc/apt/sources.list will ${baihongse}not${baizise} be replaced${normal}"
fi

echo "${bold}${baiqingse}还没写更换源的部分...${normal}"
echo ;
}

# --------------------- 询问编译安装时需要使用的线程数量 --------------------- #

function _askmt() {

while [[ $MAXCPUS = "" ]]; do
    echo -e "${green}01)${normal} Use ${cyan}all${normal} available threads (Default)"
    echo -e "${green}02)${normal} Use ${cyan}half${normal} of available threads"
    echo -e "${green}03)${normal} Use ${cyan}one${normal} thread"
    echo -e "${green}04)${normal} Use ${cyan}two${normal} threads"

  # echo -e  "${bold}${red}$lang_note_that${normal} ${bold}using more than one thread to compile may cause failure in some cases${normal}"
    read -ep "${bold}${yellow}How many threads do you want to use when compiling?${normal} (Default ${cyan}01${normal}): " version
  # echo -ne "${bold}${yellow}How many threads do you want to use when compiling?${normal} (Default ${cyan}01${normal}): " ; read -e responce

    case $responce in
        01 | 1 | "") MAXCPUS=$(nproc) ;;
        02 | 2     ) MAXCPUS=$(echo "$(nproc) / 2"|bc) ;;
        03 | 3     ) MAXCPUS=1 ;;
        04 | 4     ) MAXCPUS=2 ;;
        05 | 5     ) MAXCPUS=No ;;
        *          ) MAXCPUS=$(nproc) ;;
    esac

done

if [[ $MAXCPUS == No ]]; then
    echo -e "${bold}${baiqingse}Deluge/qBittorrent/Transmission $lang_will_be_installed from repo${normal}"
else
    echo -e "${bold}${baiqingse}[${MAXCPUS}]${normal} ${bold}thread(s) will be used when compiling${normal}"
fi

echo ; }

# --------------------- 询问是否使用 swap --------------------- #

function _askswap() {

if [[ $USESWAP = "" ]] && [[ $tram -le 1926 ]]; then

    echo -e  "${bold}${red}$lang_note_that${normal} ${bold}Your RAM is below ${red}1926MB${jiacu}, memory may got exhausted when compiling${normal}"
    read -ep "${bold}${yellow}Would you like to use swap when compiling?${normal} [${cyan}Y${normal}]es or [N]o: " version
  # echo -ne "${bold}${yellow}Would you like to use swap when compiling?${normal} [${cyan}Y${normal}]es or [N]o: " ; read -e responce

    case $responce in
        [yY] | "") USESWAP=Yes ;;
        [nN]     ) USESWAP=No  ;;
        *        ) USESWAP=Yes ;;
    esac

    if [[ $USESWAP == Yes ]]; then
        echo -e "${bold}${baiqingse} 1GB Swap ${normal} will be used"
    else
        echo -e "${bold}Swap will not be used${normal}"
    fi

echo

fi ; }

# --------------------- 询问需要安装的 qBittorrent 的版本 --------------------- #
# wget -qO- "https://github.com/qbittorrent/qBittorrent" | grep "data-name" | cut -d '"' -f2 | pr -4 -t ; echo

function _askqbt() {

while [[ $qb_version = "" ]]; do

    echo -e "${green}01)${normal} qBittorrent ${cyan}3.3.11${normal}"
    echo -e "${green}02)${normal} qBittorrent ${cyan}3.3.16${normal}"
    echo -e "${green}03)${normal} qBittorrent ${cyan}4.1.5${normal}"
#   echo -e  "${blue}11)${normal} qBittorrent ${blue}4.2.0.alpha (unstable)${normal}"
    echo -e  "${blue}30)${normal} $language_select_another_version"
    echo -e "${green}40)${normal} qBittorrent ${cyan}$QB_repo_ver${normal} from ${cyan}repo${normal}"
    echo -e   "${red}99)${normal} $lang_do_not_install qBittorrent"

    [[ $qb_installed == Yes ]] &&
    echo -e "${bailanse}${bold} ATTENTION ${normal} ${blue}${bold}$lang_yizhuang ${underline}qBittorrent ${qbtnox_ver}${normal}"

    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}99${normal}): " version
  # echo -ne "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}99${normal}): " ; read -e version

    case $version in
        01 | 1) qb_version=3.3.11 ;;
        02 | 2) qb_version=3.3.16 ;;
        03 | 3) qb_version=4.1.5 ;;
        11) qb_version=4.2.0.alpha ;;
        30) _input_version && qb_version="${input_version_num}"  ;;
        40) qb_version='Install from repo' ;;
        99) qb_version=No ;;
        * | "") qb_version=No ;;
    esac

done

[[ $(echo $qb_version | grep -oP "[0-9.]+" | awk -F '.' '{print $1}') == 3 ]] && qbt_ver_3=Yes

# 2018.12.11 改来改去，我现在有点懵逼……
qBittorrent_4_2_0_later=No
[[ $(echo $qb_version | grep -oP "[0-9.]+") ]] && version_ge $qb_version 4.1.4 && qBittorrent_4_2_0_later=Yes

if [[ $qb_version == No ]]; then

    echo "${baizise}qBittorrent will ${baihongse}not${baizise} be installed${normal}"

elif [[ $qb_version == "Install from repo" ]]; then

    sleep 0

elif [[ $qb_version == "4.2.0.alpha" ]]; then

    echo -e "${bold}${bailanse}qBittorrent ${qb_version}${normal} ${bold}$lang_will_be_installed${normal}"
  # echo -e "\n$${ZY} This is NOT a stable release${normal}"

else

    echo -e "${bold}${baiqingse}qBittorrent ${qb_version}${normal} ${bold}$lang_will_be_installed${normal}"
    [[ $qbt_ver_3 == Yes ]] && {
    echo -e "\n${bold}${bailanse}Attention${normal} ${bold}The option of qbt 3.3.x installation will be removed recently${normal}"
    echo -e "${bold}${baihongse}  注意！ ${normal} ${bold}在下一个版本会取消 qb 3.3.X 版本的安装选项${normal}" ; }

fi

if [[ $qb_version == "Install from repo" ]]; then

    echo "${bold}${baiqingse}qBittorrent $QB_repo_ver${normal} ${bold}$lang_will_be_installed from yum packages${normal}"

fi

echo ; }




# --------------------- 询问需要安装的 Deluge 版本 --------------------- #
# wget -qO- "http://download.deluge-torrent.org/source/" | grep -Eo "1\.3\.[0-9]+" | sort -u | pr -6 -t ; echo

function _askdeluge() {

while [[ $de_version = "" ]]; do

    echo -e "${green}01)${normal} Deluge ${cyan}1.3.9${normal}"
    echo -e "${green}02)${normal} Deluge ${cyan}1.3.15${normal}"
#   echo -e "${green}05)${normal} Deluge ${cyan}2.0${normal}"
#   echo -e  "${blue}11)${normal} Deluge ${blue}2.0 dev${normal} ${blue}(unstable)${normal}"
    echo -e  "${blue}30)${normal} $language_select_another_version"
    echo -e "${green}40)${normal} Deluge ${cyan}$DE_repo_ver${normal} from ${cyan}repo${normal}"
    echo -e   "${red}99)${normal} $lang_do_not_install Deluge"

    [[ $de_installed == Yes ]] &&
    echo -e "${bailanse}${bold} ATTENTION ${normal} ${blue}${bold}$lang_yizhuang ${underline}Deluge ${deluged_ver}${reset_underline}${normal}"

    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}02${normal}): " version
  # echo -ne "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}02${normal}): " ; read -e version

    case $version in
        01 | 1) de_version=1.3.9 ;;
        02 | 2) de_version=1.3.15 ;;
#       05 | 5) de_version=2.0 ;;
        11) de_version=2.0.dev ;;
        21) de_version='1.3.15_skip_hash_check' ;;
        30) _input_version && de_version="${input_version_num}" ;;
        31) _input_version && de_version="${input_version_num}" && de_test=yes &&  de_branch=yes ;;
        32) _input_version && de_version="${input_version_num}" && de_test=yes && de_version=yes ;;
        40) de_version='Install from repo' ;;
        99) de_version=No ;;
        * | "") de_version=1.3.15 ;;
    esac

done


[[ $(echo $de_version | grep -oP "[0-9.]+") ]] && { version_ge $de_version 1.3.11 || Deluge_ssl_fix_patch=Yes ; }
[[ $(echo $de_version | grep -oP "[0-9.]+") ]] && { version_ge $de_version 2.0 && Deluge_2_later=Yes || Deluge_2_later=No ; }
[[ $de_version == '1.3.15_skip_hash_check'  ]] && Deluge_1_3_15_skip_hash_check_patch=Yes


if [[ $de_version == No ]]; then

    echo "${baizise}Deluge will ${baihongse}not${baizise} be installed${normal}"

elif [[ $de_version == "Install from repo" ]]; then 

    sleep 0

elif [[ $de_version == "2.0.dev" ]]; then

    echo -e "${bold}${bailanse}Deluge ${de_version}${normal} ${bold}$lang_will_be_installed${normal}"
  # echo -e "\n${ZY} This is NOT a stable release${normal}"

else

    echo "${bold}${baiqingse}Deluge ${de_version}${normal} ${bold}$lang_will_be_installed${normal}"

fi


if [[ $de_version == "Install from repo" ]]; then 

    echo "${bold}${baiqingse}Deluge $DE_repo_ver${normal} ${bold}$lang_will_be_installed from yum packages${normal}"

fi

echo ; }

# libtorrent 1.0.11: 適用於qBittorrent4.0.0-4.1.3
# libtorrent 1.1.12: 適用於qBittorrent4.0.0或更新版本
# libtorrent 1.2.0 : qBittorrent暫未支援lt1.2系列
# qBittorrent4.1.4需要C++14進行編譯
# CentOS7自帶的GCC4.8.5只支援到C++11，所以稍後會透過SCL安裝GCC8.2 (支援C++14)
# --------------------- 询问需要安装的 libtorrent-rasterbar 版本 --------------------- #
function _lt_ver_ask() {

  [[ $DeBUG == 1 ]] && echo "lt_version=$lt_version  lt_ver=$lt_ver  lt8_support=$lt8_support  qb_version=$qb_version  de_version=$de_version"

  # 默认 lt 1.0 可用
  lt8_support=Yes
  # 当要安装 Deluge 2.0 或 qBittorrent 4.2.0(stable release) 时，lt 版本至少要 1.1.3；如果原先装了 1.0，那么这里必须升级到 1.1 或者 1.2
  # 2019.01.30 这里不去掉 unset lt_version 就容易导致 opt 失效
  [[ $Deluge_2_later == Yes || $qBittorrent_4_2_0_later == Yes ]] && lt8_support=No

  [[ $DeBUG == 1 ]] && {
  echo "Deluge_2_later=$Deluge_2_later   qBittorrent_4_2_0_later=$qBittorrent_4_2_0_later"
  echo "lt_ver=$lt_ver  lt8_support=$lt8_support  lt_ver_qb3_ok=$lt_ver_qb3_ok  lt_ver_de2_ok=$lt_ver_de2_ok" ; }

while [[ $lt_version = "" ]]; do

    [[ $lt8_support == Yes ]] &&
    echo -e "${green}01)${normal} libtorrent-rasterbar ${cyan}1.0.11${normal} (${blue}RC_1_0${normal} branch)"
    echo -e "${green}02)${normal} libtorrent-rasterbar ${cyan}1.1.12${normal} (${blue}RC_1_1${normal} branch)"
    echo -e "${green}03)${normal} libtorrent-rasterbar ${blue}1.2.0 ${normal} (${blue}RC_1_2${normal} branch)"
    echo -e  "${blue}30)${normal} $language_select_another_version"
    [[ $lt_ver ]] && [[ $lt_ver_qb3_ok == Yes ]] &&
    echo -e "${green}99)${normal} libtorrent-rasterbar ${cyan}$lt_ver${normal} which is already installed"
  # echo -e "${bailanse}${bold} ATTENTION ${normal}${blue} both Deluge and qBittorrent use libtorrent-rasterbar \n            as torrent backend"

    # 已安装 libtorrent-rasterbar 且不使用 Deluge 2.0 或者 qBittorrent 4.2.0
    if [[ $lt_ver ]] && [[ $lt_ver_qb3_ok == Yes ]] && [[ $lt8_support == Yes ]]; then
            while [[ $lt_version == "" ]]; do
					read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}99${normal}): " version
                    case $version in
                          01 | 1) lt_version=RC_1_0 ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          99    ) lt_version=No ;;
                          ""    ) lt_version=No ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    # 已安装 libtorrent-rasterbar 的版本低于 1.0.6，无法用于编译 qBittorrent 3.3.x and later（但也不需要 1.1）
    elif [[ $lt_ver ]] && [[ $lt_ver_qb3_ok == No ]] && [[ ! $qb_version == No ]]; then
            while [[ $lt_version == "" ]]; do
                    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}01${normal}): " version
                    case $version in
                          01 | 1) lt_version=RC_1_0 ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          99    ) echo -e "\n${CW} qBittorrent 3.3 and later requires libtorrent-rasterbar 1.0.6 and later${normal}\n" ;;
                          ""    ) lt_version=RC_1_0 ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    # 已安装 libtorrent-rasterbar 且需要使用 Deluge 2.0 或者 qBittorrent 4.2.0，且系统里已经安装的 libtorrent-rasterbar 支持
    # 2018.12.03 发现这里写的有问题，试着更正下
    elif [[ $lt_ver ]] && [[ $lt8_support == No ]] && [[ $lt_ver_de2_ok == Yes ]]; then
            while [[ $lt_version == "" ]]; do
                    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}99${normal}): " version
                    case $version in
                          01 | 1) echo -e "\n${CW} Deluge 2.0 or qBittorrent 4.2.0 requires libtorrent-rasterbar 1.1.3 or later${normal}\n" ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          99    ) lt_version=No ;;
                          ""    ) lt_version=No ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    # 已安装 libtorrent-rasterbar 且需要使用 Deluge 2.0 或者 qBittorrent 4.2.0，但系统里已经安装的 libtorrent-rasterbar 不支持
    elif [[ $lt_ver ]] && [[ $lt8_support == No ]] && [[ $lt_ver_de2_ok == No ]]; then
            while [[ $lt_version == "" ]]; do
                    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}02${normal}): " version
                    case $version in
                          01 | 1) echo -e "\n${CW} Deluge 2.0 or qBittorrent 4.2.0 requires libtorrent-rasterbar 1.1.3 or later${normal}\n" ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          99    ) echo -e "\n${CW} Deluge 2.0 or qBittorrent 4.2.0 requires libtorrent-rasterbar 1.1.3 or later${normal}\n" ;;
                          ""    ) lt_version=RC_1_1 ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    # 未安装 libtorrent-rasterbar 且不使用 Deluge 2.0 或者 qBittorrent 4.2.0
    elif [[ ! $lt_ver ]] && [[ $lt8_support == Yes ]]; then
            while [[ $lt_version == "" ]]; do
                    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}02${normal}): " version
                    case $version in
                          01 | 1) lt_version=RC_1_0 ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          99    ) echo -e "\n${CW} libtorrent-rasterbar is a must for Deluge or qBittorrent, so you have to install it${normal}\n" ;;
                          ""    ) lt_version=RC_1_1 ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    # 未安装 libtorrent-rasterbar 且要使用 Deluge 2.0 或者 qBittorrent 4.2.0
    elif [[ ! $lt_ver ]] && [[ $lt8_support == No ]]; then
            while [[ $lt_version == "" ]]; do
                    echo -ne "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}02${normal}): " ; read -e version
                    case $version in
                          01 | 1) echo -e "\n${CW} Deluge 2.0 or qBittorrent 4.2.0 requires libtorrent-rasterbar 1.1.3 or later${normal}\n" ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          99    ) echo -e "\n${CW} libtorrent-rasterbar is a must for Deluge or qBittorrent, so you have to install it${normal}\n" ;;
                          ""    ) lt_version=RC_1_1 ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    else
            while [[ $lt_version == "" ]]; do
                    echo -e "\n${bold}${yellow}你发现了一个 Bug！请带着以下信息联系作者……${normal}\n"
                    echo "Deluge_2_later=$Deluge_2_later   qBittorrent_4_2_0_later=$qBittorrent_4_2_0_later"
                    echo "lt_ver=$lt_ver  lt8_support=$lt8_support  lt_ver_qb3_ok=$lt_ver_qb3_ok  lt_ver_de2_ok=$lt_ver_de2_ok"
                    echo -ne "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}02${normal}): " ; read -e version
                    case $version in
                          01 | 1) lt_version=RC_1_0 ;;
                          02 | 2) lt_version=RC_1_1 ;;
                          03 | 3) lt_version=RC_1_2 ;;
                          30    ) _input_version_lt && lt_version="${input_version_num}" ;;
                          *     ) echo -e "\n${CW} Please input a valid opinion${normal}\n" ;;
                    esac
            done

    fi

done

  lt_display_ver=$( echo "$lt_version" | sed "s/_/\./g" | sed "s/libtorrent-//" )
  [[ $lt_version == RC_1_0  ]] && lt_display_ver=1.0.11
  [[ $lt_version == RC_1_1  ]] && lt_display_ver=1.1.12
  [[ $lt_version == RC_1_2  ]] && lt_display_ver=1.2.0
  [[ $lt_version == master  ]] && lt_display_ver=1.2.0
  # 检测版本号速度慢了点，所以还是手动指定
  if [[ $lt_version != No ]]; then
    echo "${baiqingse}${bold}libtorrent-rasterbar ${lt_display_ver}${normal} ${bold}$lang_will_be_installed${normal}"
  else
    unset lt_version
    echo "${baizise}libtorrent-rasterbar will ${baihongse}not${baizise} be installed${normal}"
  fi

[[ $DeBUG == 1 ]] && {
echo "Deluge_2_later=$Deluge_2_later   qBittorrent_4_2_0_later=$qBittorrent_4_2_0_later
lt_ver=$lt_ver  lt8_support=$lt8_support  lt_ver_qb3_ok=$lt_ver_qb3_ok  lt_ver_de2_ok=$lt_ver_de2_ok
lt_version=$lt_version" ; }

echo ; }

# --------------------- 询问需要安装的 rTorrent 版本 --------------------- #
function _askrt() {
  branch=branch
  while [[ $rt_version = "" ]]; do
    echo -e "${green}01)${normal} rTorrent ${cyan}0.9.7${normal}/libTorrent ${cyan}0.13.7${normal} with IPv6 support"
    echo -e   "${red}99)${normal} $lang_do_not_install rTorrent" 
    
    [[ $rt_installed == Yes ]] &&
    echo -e "${bailanse}${bold} ATTENTION ${normal} ${blue}${bold}$lang_yizhuang ${underline}rTorrent ${rtorrent_ver}${normal}" && version=99
    [[ $rt_installed != Yes ]] && read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}99${normal}): " version
    # echo -ne "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}99${normal}): " ; read -e version
    case $version in
        01 | 1) rt_version=0.9.7 && libTorrent_version=0.13.7 ;;
        99) rt_version=No ;;
        "" | *) rt_version=No ;;
    esac
  done
  
  if [[ $rt_version == No ]]; then
    echo "${baizise}rTorrent will ${baihongse}not${baizise} be installed${normal}"
    InsFlood='No rTorrent'
  else
    echo "${bold}${baiqingse}rTorrent ${rt_version}${normal} ${bold}$lang_will_be_installed${normal}"
  fi
  
echo ; }
# --------------------- 询问是否安装 flood --------------------- #

function _askflood() {
  while [[ $InsFlood = "" ]]; do
    read -ep "${bold}${yellow}$lang_would_you_like_to_install flood? ${normal} [Y]es or [${cyan}N${normal}]o: " responce
    # echo -ne "${bold}${yellow}$lang_would_you_like_to_install flood? ${normal} [Y]es or [${cyan}N${normal}]o: " ; read -e responce
  
    case $responce in
        [yY]      ) InsFlood=Yes ;;
        [nN] | "" ) InsFlood=No  ;;
        *         ) InsFlood=No ;;
    esac
  done
  
  if [[ $InsFlood == Yes ]]; then
    echo "${bold}${baiqingse}Flood${normal} ${bold}$lang_will_be_installed${normal}"
  else
    echo "${baizise}Flood will ${baihongse}not${baizise} be installed${normal}"
  fi
  
echo ; }
# --------------------- 询问需要安装的 Transmission 版本 --------------------- #
# wget -qO- "https://github.com/transmission/transmission" | grep "data-name" | cut -d '"' -f2 | pr -3 -t ; echo

function _asktr() {

while [[ $tr_version = "" ]]; do

    echo -e "${green}01)${normal} Transmission ${cyan}2.77${normal}" &&
    echo -e "${green}02)${normal} Transmission ${cyan}2.82${normal}" &&
    echo -e "${green}03)${normal} Transmission ${cyan}2.84${normal}" &&
    echo -e "${green}04)${normal} Transmission ${cyan}2.92${normal}"
    echo -e "${green}05)${normal} Transmission ${cyan}2.93${normal}"
    echo -e "${green}06)${normal} Transmission ${cyan}2.94${normal}"
    echo -e  "${blue}30)${normal} $language_select_another_version"
    echo -e "${green}40)${normal} Transmission ${cyan}$TR_repo_ver${normal} from ${cyan}repo${normal}"

    echo -e   "${red}99)${normal} $lang_do_not_install Transmission"

    [[ $tr_installed == Yes ]] &&
    echo -e "${bailanse}${bold} ATTENTION ${normal} ${blue}${bold}$lang_yizhuang ${underline}Transmission ${trd_ver}${normal}"

    read -ep "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}06${normal}): " version
  # echo -ne "${bold}${yellow}$which_version_do_you_want${normal} (Default ${cyan}06${normal}): " ; read -e version

    case $version in
            01 | 1) tr_version=2.77 ;;
            02 | 2) tr_version=2.82 ;;
            03 | 3) tr_version=2.84 ;;
            04 | 4) tr_version=2.92 ;;
            05 | 5) tr_version=2.93 ;;
            06 | 6) tr_version=2.94 ;;
            11) tr_version=2.92 && TRdefault=No ;;
            12) tr_version=2.93 && TRdefault=No ;;
            13) tr_version=2.94 && TRdefault=No ;;
            30) _input_version && tr_version="${input_version_num}" ;;
            31) _input_version && tr_version="${input_version_num}" && TRdefault=No ;;
            40) tr_version='Install from repo' ;;
            99) tr_version=No ;;
            "" | *) tr_version=2.94;;
    esac

done


if [[ $tr_version == No ]]; then

    echo "${baizise}Transmission will ${baihongse}not${baizise} be installed${normal}"

else

    if [[ $tr_version == "Install from repo" ]]; then 

        sleep 0
    else

        echo "${bold}${baiqingse}Transmission ${tr_version}${normal} ${bold}$lang_will_be_installed${normal}"

    fi


    if [[ $tr_version == "Install from repo" ]]; then 

        echo "${bold}${baiqingse}Transmission $TR_repo_ver${normal} ${bold}$lang_will_be_installed from repository${normal}"

    fi

fi

echo ; }

# --------------------- 询问是否需要安装 Flexget --------------------- #

function _askflex() {

while [[ $InsFlex = "" ]]; do

    [[ $flex_installed == Yes ]] && echo -e "${bailanse}${bold} ATTENTION ${normal} ${blue}${bold}$lang_yizhuang flexget${normal}"
    read -ep "${bold}${yellow}$lang_would_you_like_to_install Flexget?${normal} [${cyan}Y${normal}]es or [N]o: " responce
  # echo -ne "${bold}${yellow}$lang_would_you_like_to_install Flexget?${normal} [Y]es or [${cyan}N${normal}]o: " ; read -e responce

    case $responce in
        [yY]  ) InsFlex=Yes ;;
        [nN]  ) InsFlex=No ;;
        *     ) InsFlex=Yes ;;
    esac

done

if [ $InsFlex == Yes ]; then
    echo -e "${bold}${baiqingse}Flexget${normal} ${bold}$lang_will_be_installed${normal}\n"
else
    echo -e "${baizise}Flexget will ${baihongse}not${baizise} be installed${normal}\n"
fi ; }

# --------------------- 询问是否需要安装 rclone --------------------- #

function _askrclone() {

while [[ $InsRclone = "" ]]; do

    [[ $rclone_installed == Yes ]] && echo -e "${bailanse}${bold} ATTENTION ${normal} ${blue}${bold}$lang_yizhuang rclone${normal}"
    read -ep "${bold}${yellow}$lang_would_you_like_to_install rclone?${normal} [Y]es or [${cyan}N${normal}]o: " responce
  # echo -ne "${bold}${yellow}$lang_would_you_like_to_install rclone?${normal} [Y]es or [${cyan}N${normal}]o: " ; read -e responce

    case $responce in
        [yY]   ) InsRclone=Yes ;;
        [nN]   ) InsRclone=No  ;;
        *      ) InsRclone=No ;;
    esac

done

if [[ $InsRclone == Yes ]]; then
    echo -e "${bold}${baiqingse}rclone${normal} ${bold}$lang_will_be_installed${normal}\n"
else
    echo -e "${baizise}rclone will ${baihongse}not${baizise} be installed${normal}\n"
fi ; }

# --------------------- BBR 相关 --------------------- #
# 检查是否已经启用BBR、BBR 魔改版
function check_bbr_status() { tcp_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
if [[ $tcp_control =~ (bbr|bbr_powered|nanqinlang|tsunami) ]]; then bbrinuse=Yes ; else bbrinuse=No ; fi ; }

# 检查理论上内核是否支持原版 BBR
function check_kernel_version() {
kernel_vvv=$(uname -r | cut -d- -f1)
[[ ! -z $kernel_vvv ]] && version_ge $kernel_vvv 4.9 && bbrkernel=Yes || bbrkernel=No ; }

# [[ ` ls /lib/modules/\$(uname -r)/kernel/net/ipv4 | grep tcp_bbr.ko ` ]]

# 询问是否安装BBR
function _askbbr() { check_bbr_status

if [[ $bbrinuse == Yes ]]; then

    echo -e "${bold}${yellow}TCP BBR has been installed. Skip ...${normal}"
    InsBBR=Already\ Installed

else

    check_kernel_version

    while [[ $InsBBR = "" ]]; do

        if [[ $bbrkernel == Yes ]]; then
            echo -e "${bold}Your kernel is newer than ${green}4.9${normal}${bold}, but BBR is not enabled${normal}"
            read -ep "${bold}${yellow}Would you like to use BBR? ${normal} [${cyan}Y${normal}]es or [N]o: " responce

            case $responce in
                [yY]  ) InsBBR=To\ be\ enabled ;;
                [nN]  ) InsBBR=No ;;
                *     ) InsBBR=To\ be\ enabled ;;
            esac

        else
         echo -e "${bold}Your kernel is below than ${green}4.9${normal}${bold} while BBR requires at least a ${green}4.9${normal}${bold} kernel"
         echo -e "Checking for new kernel...Take a few seconds"
         BBR_kernel_ver=` yum --enablerepo=elrepo-kernel list kernel-ml | grep -Eo "[3-6]\.[0-9.]+" | head -n1 `
         echo -e "A new kernel (${BBR_kernel_ver}) $lang_will_be_installed"
            echo -ne "${bold}${yellow}$lang_would_you_like_to_install BBR? ${normal} [Y]es or [${cyan}N${normal}]o: " ; read -e responce

            case $responce in
                [yY]      ) InsBBR=Yes ;;
                [nN] | "" ) InsBBR=No ;;
                *         ) InsBBR=No ;;
            esac

        fi

    done

    # 主要是考虑到使用 opt 的情况
   [[ $InsBBR == Yes ]] && [[ $bbrkernel == Yes ]] && InsBBR=To\ be\ enabled

    if [[ $InsBBR == Yes ]]; then
        echo "${bold}${baiqingse}TCP BBR${normal} ${bold}$lang_will_be_installed${normal}"
    elif [[ $InsBBR == To\ be\ enabled ]]; then
        echo "${bold}${baiqingse}TCP BBR${normal} ${bold}will be enabled${normal}"
    else
        echo "${baizise}TCP BBR will ${baihongse}not${baizise} be installed${normal}"
    fi

fi ; echo ; }

# --------------------- 询问是否需要修改一些设置 --------------------- #

function _asktweaks() {

while [[ $UseTweaks = "" ]]; do

#   read -ep "${bold}${yellow}Would you like to configure some system settings? ${normal} [${cyan}Y${normal}]es or [N]o: " responce
    echo -ne "${bold}${yellow}Would you like to do some system tweaks? ${normal} [${cyan}Y${normal}]es or [N]o: " ; read -e responce

    case $responce in
        [yY] | "" ) UseTweaks=Yes ;;
        [nN]      ) UseTweaks=No ;;
        *         ) UseTweaks=Yes ;;
    esac

done

if [[ $UseTweaks == Yes ]]; then
    echo "${bold}${baiqingse}System tweaks${normal} ${bold}will be configured${normal}"
else
    echo "${baizise}System tweaks will ${baihongse}not${baizise} be configured${normal}"
fi

echo ; }

# --------------------- 输出所用时间 --------------------- #
function _time() {
endtime=$(date +%s)
timeused=$(( $endtime - $starttime ))
if [[ $timeused -gt 60 && $timeused -lt 3600 ]]; then
    timeusedmin=$(expr $timeused / 60)
    timeusedsec=$(expr $timeused % 60)
    echo -e " ${baiqingse}${bold}The $timeWORK took about ${timeusedmin} min ${timeusedsec} sec${normal}"
elif [[ $timeused -ge 3600 ]]; then
    timeusedhour=$(expr $timeused / 3600)
    timeusedmin=$(expr $(expr $timeused % 3600) / 60)
    timeusedsec=$(expr $timeused % 60)
    echo -e " ${baiqingse}${bold}The $timeWORK took about ${timeusedhour} hour ${timeusedmin} min ${timeusedsec} sec${normal}"
else
    echo -e " ${baiqingse}${bold}The $timeWORK took about ${timeused} sec${normal}"
fi ; }

# --------------------- 询问是否继续 --------------------- #

function _askcontinue() {

echo -e "\n${bold}Please check the following information${normal}"
echo
echo '####################################################################'
echo
echo "                  ${cyan}${bold}Username${normal}      ${bold}${yellow}${ANUSER}${normal}"
echo "                  ${cyan}${bold}Password${normal}      ${bold}${yellow}${ANPASS}${normal}"
echo
echo "                  ${cyan}${bold}qBittorrent${normal}   ${bold}${yellow}${qb_version}${normal}"
echo "                  ${cyan}${bold}Deluge${normal}        ${bold}${yellow}${de_version}${normal}"
[[ ! $de_version == No ]] || [[ ! $qb_version == No ]] &&
echo "                  ${cyan}${bold}libtorrent${normal}    ${bold}${yellow}${lt_display_ver}${normal}"
echo "                  ${cyan}${bold}rTorrent${normal}      ${bold}${yellow}${rt_version}${normal}"
[[ ! $rt_version == No ]] &&
echo "                  ${cyan}${bold}Flood${normal}         ${bold}${yellow}${InsFlood}${normal}"
echo "                  ${cyan}${bold}Transmission${normal}  ${bold}${yellow}${tr_version}${normal}"
echo "                  ${cyan}${bold}Flexget${normal}       ${bold}${yellow}${InsFlex}${normal}"
echo "                  ${cyan}${bold}rclone${normal}        ${bold}${yellow}${InsRclone}${normal}"
echo "                  ${cyan}${bold}BBR${normal}           ${bold}${yellow}${InsBBR}${normal}"
echo "                  ${cyan}${bold}System tweak${normal}  ${bold}${yellow}${UseTweaks}${normal}"
echo "                  ${cyan}${bold}Threads${normal}       ${bold}${yellow}${MAXCPUS}${normal}"
echo
echo '####################################################################'
echo
echo -e "${bold}If you want to stop, Press ${baihongse}Ctrl+C${jiacu} ; or Press ${bailvse}ENTER${normal} ${bold}to start${normal}"
[[ ! $ForceYes == 1 ]] && read input
echo -e "${bold}${magenta}The selected softwares $lang_will_be_installed, this may take between${normal}"
echo -e "${bold}${magenta}1 - 100 minutes depending on your systems specs and your selections${normal}\n"
}

# --------------------- 替换系统源 --------------------- #
function _setsources() {

[[ $USESWAP == Yes ]] && { 
  echo -ne "Enable Swap space ..."
  _use_swap & spinner $!
  _check_status SwapON ; }
#if [[ $aptsources == Yes ]]; then
#    cp /etc/apt/sources.list /etc/apt/sources.list."$(date "+%Y%m%d.%H%M")".bak
#else
#    apt-get -y update
#fi

  echo -e "Replace system source ... ${green}${bold}DONE${normal}"
}
# --------------------- 创建用户、准备工作 --------------------- #
function _setuser() {
  if id -u ${ANUSER} >/dev/null 2>&1; then
    echo "${ANUSER}:${ANPASS}" | chpasswd
    echo -e "${cyan}${ANUSER}${normal} already exists, Change Password ... ${green}${bold}DONE${normal}"
  else
    adduser ${ANUSER} -m >> $OutputLOG 2>&1
    echo "${ANUSER}:${ANPASS}" | chpasswd
    echo -e "Adduser ${cyan}${ANUSER}${normal} ... ${green}${bold}DONE${normal}"
  fi

  echo -ne "Copy file ... "
  [[ -d /etc/inexistence ]] && rm -rf /etc/inexistence
  git clone --depth=1 https://github.com/xiahuaijia/inexistence-CentOS /etc/inexistence >> $OutputLOG 2>&1
  mkdir -p $SCLocation $LOCKLocation
  mkdir -p /etc/inexistence/01.Log/INSTALLATION/packages /etc/inexistence/00.Installation/MAKE
  chmod -R 777 /etc/inexistence
  
  # 脚本设置
  mkdir -p /etc/inexistence/00.Installation
  mkdir -p /etc/inexistence/01.Log
  mkdir -p /etc/inexistence/03.Files
  mkdir -p /var/www/h5ai
  
  touch /etc/inexistence/01.Log/installed.log
cat>>/etc/inexistence/01.Log/installed.log<<EOF
如果要截图请截完整点，包含下面所有信息
CPU        : $cname"
Cores      : ${freq} MHz, ${cpucores} Core(s), ${cputhreads} Thread(s)"
Mem        : $tram MB ($uram MB Used)"
Disk       : $disk_total_size GB ($disk_used_size GB Used)
OS         : $DISTRO $osversion ($arch)
Kernel     : $kern
ASN & ISP  : $asnnnnn, $isppppp
Location   : $cityyyy, $regionn, $country
#################################
INEXISTENCEVER=${INEXISTENCEVER}
INEXISTENCEDATE=${INEXISTENCEDATE}
SETUPDATE=$(date "+%Y.%m.%d.%H.%M.%S")
MAXDISK=$(df -k | sort -rn -k4 | awk '{print $1}' | head -1)
HOMEUSER=$(ls /home)
#################################
MAXCPUS=${MAXCPUS}
APTSOURCES=${aptsources}
qb_version=${qb_version}
de_version=${de_version}
rt_version=${rt_version}
tr_version=${tr_version}
lt_version=${lt_version}
FLEXGET=${InsFlex}
RCLONE=${InsRclone}
BBR=${InsBBR}
USETWEAKS=${UseTweaks}
FLOOD=${InsFlood}
#################################
如果要截图请截完整点，包含上面所有信息
EOF

  ln -s /etc/inexistence /var/www/h5ai/inexistence >> $OutputLOG 2>&1
  ln -s /etc/inexistence /home/${ANUSER}/inexistence >> $OutputLOG 2>&1
  cp -f /etc/inexistence/00.Installation/script/* /usr/local/bin >> $OutputLOG 2>&1
  echo -e "${green}${bold}DONE${normal}"
}

# --------------------- 安装 libtorrent-rasterbar --------------------- #

function _install_lt() {

[[ $DeBUG == 1 ]] && {
echo "Deluge_2_later=$Deluge_2_later   qBittorrent_4_2_0_later=$qBittorrent_4_2_0_later
lt_ver=$lt_ver  lt8_support=$lt8_support  lt_ver_qb3_ok=$lt_ver_qb3_ok  lt_ver_de2_ok=$lt_ver_de2_ok
lt_version=$lt_version" ; }

if [[ $arch == x86_64 ]]; then

if   [[ $lt_version == RC_1_0 ]]; then
    __install_lt -b RC_1_0
elif [[ $lt_version == RC_1_1 ]]; then
    __install_lt -b RC_1_1
elif [[ $lt_version == RC_1_2 ]]; then
    __install_lt -b RC_1_2
else
    __install_lt -v $lt_version
fi

fi ; }


function spinner() {
    local pid=$1
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${bold}${yellow}%c${normal}]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function __install_lt(){ 
    while true; do
    case "$1" in
    -v ) version="$2"  ; shift ; shift ;;
    -b ) branch="$2"   ; shift ; shift ;;
     * ) break ;;
  esac
done

###################################################
# Determin RC_1_0 and RC_1_1's version
 [[ $branch == RC_1_0 ]] && version=1.0.11
 [[ $branch == RC_1_1 ]] && version=1.1.12
 [[ $branch == RC_1_2 ]] && version=1.2.0
 # 1.2.0 https://centos.pkgs.org/7/centos-sclo-rh-testing-x86_64/rh-mariadb101-boost-1.58.0-12.el7.x86_64.rpm.html
# Transform version to branch
[[ $( echo $version | grep -Eo "[012]\.[0-9]+\.[0-9]+" ) ]] && branchV=$( echo $version | sed "s/\./_/g" )

[[ $DeBUG == 1 ]] && echo -e "version=$version, branch=$branch, branchV=$branchV"

#[ ! -z $branch ] && [ -z $version ] && version=$( wget -qO- https://github.com/arvidn/libtorrent/raw/$branch/include/libtorrent/version.hpp | grep LIBTORRENT_VERSION | tail -n1 | grep -oE "[0-9.]+\"" | sed "s/.0\"//" )

# Random number for marking different installations
#RN=$(shuf -i 1-999 -n1)

mkdir -p $SCLocation
cd       $SCLocation

echo -ne "Installing libtorrent-rasterbar build dependencies ..."
yum groupinstall -y 'Development Tools' >> $OutputLOG 2>&1 &&
yum install -y boost-devel openssl-devel >> $OutputLOG 2>&1 &&
touch /tmp/$Installation_status_prefix.ltd.1.lock  & spinner $!
_check_status ltd 

if [[ ` echo $branch | grep -Eo "[012]_[0-9]_[0-9]+" ` ]]; then
  echo -ne "Installing libtorrent-rasterbar ${bold}${cyan}$version${normal} from source codes ..."
else
  echo -ne "Installing libtorrent-rasterbar ${bold}$branch branch (${cyan}$version${jiacu})${normal} from source codes ..."
fi

_install_lt_source & spinner $!
_check_status lt
}

# Install from source codes
function _install_lt_source() {
  cd /etc/inexistence/00.Installation/MAKE

  wget -qO libtorrent-rasterbar-$version.tar.gz "https://github.com/arvidn/libtorrent/releases/download/libtorrent_$branchV/libtorrent-rasterbar-$version.tar.gz"
  #git clone --depth=1 -b $branch https://github.com/arvidn/libtorrent libtorrent-$version >> $OutputLOG 2>&1

  tar zxf libtorrent-rasterbar-$version.tar.gz
  mv libtorrent-rasterbar-$version libtorrent-$version
  cd libtorrent-$version

  # See here for details: https://github.com/qbittorrent/qBittorrent/issues/6383
  sed -i "s/+ target_specific(),/+ target_specific() + ['-std=c++11'],/" bindings/python/setup.py

  # For both Deluge and qBittorrent
  ./configure --enable-python-binding --with-libiconv --prefix=/usr --disable-debug --enable-encryption --with-libgeoip=system CXXFLAGS=-std=c++11 >> $OutputLOG 2>&1 >> $OutputLOG 2>&1

  make -j$MAXCPUS >> $OutputLOG 2>&1
  sleep 2
  strip -s bindings/python/build/lib.linux-x86_64-2.7/libtorrent.so
  make install >> $OutputLOG 2>&1

  # qB 专用 ln
  ln -s /usr/lib/pkgconfig/libtorrent-rasterbar.pc /usr/lib64/pkgconfig/libtorrent-rasterbar.pc >> $OutputLOG 2>&1
  [[ $branch == RC_1_0 ]] && ln -s /usr/lib/libtorrent-rasterbar.so.8 /usr/lib64/libtorrent-rasterbar.so.8 >> $OutputLOG 2>&1
  [[ $branch == RC_1_1 ]] && ln -s /usr/lib/libtorrent-rasterbar.so.9 /usr/lib64/libtorrent-rasterbar.so.9 >> $OutputLOG 2>&1

  ldconfig
  
  if [[ ` python -c "import libtorrent; print libtorrent.version" | grep -Eo "[012]\.[0-9]+\.[0-9]+" ` == $version ]]; then
    touch /tmp/$Installation_status_prefix.lt.1.lock
  else
    touch /tmp/$Installation_status_prefix.lt.2.lock
  fi
}

# --------------------- 安装 qBittorrent --------------------- #

function _installqbt() {

  if [[ $qb_version == "Install from repo" ]]; then
    yum install -y qbittorrent-nox >> $OutputLOG 2>&1
  else
    [[ `  rpm -qa | grep -c qbittorrent  ` != 0 ]] && yum remove -y qbittorrent qbittorrent-nox >> $OutputLOG 2>&1

    # if [[ $OSVERSION != 7 ]]; then
        yum groupinstall -y "Development Tools" >> $OutputLOG 2>&1
        yum install -y qt-devel boost-devel qt5-qtbase-devel qt5-linguist centos-release-scl >> $OutputLOG 2>&1
        yum install -y devtoolset-8-gcc* >> $OutputLOG 2>&1
        
    # else

        # yum install -y qtbase5-dev qttools5-dev-tools libqt5svg5-dev

    # fi

    cd /etc/inexistence/00.Installation/MAKE

    qb_version=`echo $qb_version | grep -oE [0-9.]+`
    # git clone https://github.com/qbittorrent/qBittorrent qBittorrent-$qb_version
    wget -qO qBittorrent-$qb_version.tar.gz https://github.com/qbittorrent/qBittorrent/archive/release-$qb_version.tar.gz
    tar xf qBittorrent-$qb_version.tar.gz ; rm -f qBittorrent-$qb_version.tar.gz
    cd qBittorrent-release-$qb_version

    #if [[ $qb_version == 4.2.0 ]]; then
    #    git checkout master
    #elif [[ $qb_version == 4.1.2 ]]; then
    #    git checkout release-$qb_version
    #    git config --global user.email "you@example.com"
    #    git config --global user.name "Your Name"
    #    git cherry-pick 262c3a7
    #else
    #    git checkout release-$qb_version
    #fi

    scl enable devtoolset-8 "./configure --prefix=/usr --disable-gui --disable-debug CPPFLAGS=-I/usr/include/qt5 CXXFLAGS=-std=c++11 >> $OutputLOG 2>&1"
    scl enable devtoolset-8 "make -j$MAXCPUS >> $OutputLOG 2>&1"
    scl enable devtoolset-8 "make install >> $OutputLOG 2>&1"

    cd
    
    if [[ ` qbittorrent-nox --version 2>&1 | awk '{print $2}' | sed "s/v//" ` == $qb_version ]]; then
      touch /tmp/$Installation_status_prefix.installqbt.1.lock
    else
      touch /tmp/$Installation_status_prefix.installqbt.2.lock
    fi

  fi
}

# --------------------- 设置 qBittorrent --------------------- #

function _setqbt() {
  [[ -d /root/.config/qBittorrent ]] && { rm -rf /root/.config/qBittorrent.old ; mv /root/.config/qBittorrent /root/.config/qBittorrent.old ; }
  # [[ -d /home/${ANUSER}/.config/qBittorrent ]] && rm -rf /home/${ANUSER}/qbittorrent.old && mv /home/${ANUSER}/.config/qBittorrent /root/.config/qBittorrent.old
  mkdir -p /home/${ANUSER}/qbittorrent/{download,torrent,watch} /var/www /root/.config/qBittorrent  #/home/${ANUSER}/.config/qBittorrent
  chmod -R 777 /home/${ANUSER}/qbittorrent
  chown -R ${ANUSER}:${ANUSER} /home/${ANUSER}/qbittorrent  #/home/${ANUSER}/.config/qBittorrent
  chmod -R 666 /etc/inexistence/01.Log  #/home/${ANUSER}/.config/qBittorrent
  rm -rf /var/www/h5ai/qbittorrent
  ln -s /home/${ANUSER}/qbittorrent/download /var/www/h5ai/qbittorrent
  # chown www-data:www-data /var/www/h5ai/qbittorrent
  
  cp -f /etc/inexistence/00.Installation/template/config/qBittorrent.conf /root/.config/qBittorrent/qBittorrent.conf  #/home/${ANUSER}/.config/qBittorrent/qBittorrent.conf
  QBPASS=$(python /etc/inexistence/00.Installation/script/special/qbittorrent.userpass.py ${ANPASS})
  sed -i "s/SCRIPTUSERNAME/${ANUSER}/g" /root/.config/qBittorrent/qBittorrent.conf  #/home/${ANUSER}/.config/qBittorrent/qBittorrent.conf
  sed -i "s/SCRIPTQBPASS/${QBPASS}/g" /root/.config/qBittorrent/qBittorrent.conf  #/home/${ANUSER}/.config/qBittorrent/qBittorrent.conf
  
  cp -f /etc/inexistence/00.Installation/template/systemd/qbittorrent.service /etc/systemd/system/qbittorrent.service
  systemctl daemon-reload
  systemctl enable qbittorrent >> $OutputLOG 2>&1
  systemctl start qbittorrent
  # systemctl enable qbittorrent@${ANUSER}
  # systemctl start qbittorrent@${ANUSER}
  
  touch /tmp/$Installation_status_prefix.setqbt.1.lock
}

# --------------------- 安装 Deluge --------------------- #
function _installde() {
    if [[ $de_test == yes ]]; then

        [[ $de_version == yes ]] && bash <(wget -qO- https://github.com/xiahuaijia/inexistence-CentOS/raw/master/00.Installation/install/install_deluge) -v $de_version
        [[ $de_branch  == yes ]] && bash <(wget -qO- https://github.com/xiahuaijia/inexistence-CentOS/raw/master/00.Installation/install/install_deluge) -b $de_version &&
        wget -q https://github.com/Aniverse/filesss/raw/master/TorrentGrid.js -O /usr/lib/python2.7/dist-packages/deluge-1.3.15.dev0-py2.7.egg/deluge/ui/web/js/deluge-all/TorrentGrid.js

    else

    if [[ $de_version == "Install from repo" ]]; then
        yum install -y deluge deluge-web deluge-common deluge-console deluge-gtk >> $OutputLOG 2>&1
    else
        # 安装 Deluge 依赖
        yum install -y GeoIP SOAPpy boost-filesystem boost-python boost-system boost-thread pyOpenSSL python-chardet python-fpconst python-simplejson python-twisted-core python-zope-interface pyxdg rb_libtorrent rb_libtorrent-python python-beaker python-mako python-markupsafe python-twisted-web gettext python-GeoIP rb_libtorrent-python2 python-setproctitle python-pillow python intltool xdg-utils python-mako gnome-python2 >> $OutputLOG 2>&1

        # Deluge 2.0 需要高版本的这些
        [[ $Deluge_2_later == Yes ]] &&
        pip install --upgrade twisted pillow rencode pyopenssl >> $OutputLOG 2>&1

        cd /etc/inexistence/00.Installation/MAKE

    if [[ $Deluge_1_3_15_skip_hash_check_patch == Yes ]]; then
        export de_version=1.3.15
        wget -qO deluge-$de_version.tar.gz https://github.com/Aniverse/BitTorrentClientCollection/raw/master/Deluge/deluge-$de_version.skip.tar.gz
        tar xf deluge-$de_version.tar.gz ; rm -f deluge-$de_version.tar.gz
        cd deluge-$de_version
    elif [[ $de_version == 2.0.dev ]]; then
        git clone -b develop https://github.com/deluge-torrent/deluge deluge-$de_version >> $OutputLOG 2>&1
        cd deluge-$de_version
    else
        wget -q http://download.deluge-torrent.org/source/deluge-$de_version.tar.gz
        tar xf deluge-$de_version.tar.gz ; rm -f deluge-$de_version.tar.gz
        cd deluge-$de_version
    fi

    ### 修复稍微新一点的系统（比如 Debian 8）（Ubuntu 14.04 没问题）下 RPC 连接不上的问题。这个问题在 Deluge 1.3.11 上已解决
    ### http://dev.deluge-torrent.org/attachment/ticket/2555/no-sslv3.diff
    ### https://github.com/deluge-torrent/deluge/blob/deluge-1.3.9/deluge/core/rpcserver.py
    ### https://github.com/deluge-torrent/deluge/blob/deluge-1.3.11/deluge/core/rpcserver.py

    if [[ $Deluge_ssl_fix_patch == Yes ]]; then
        sed -i "s/SSL.SSLv3_METHOD/SSL.SSLv23_METHOD/g" deluge/core/rpcserver.py
        sed -i "/        ctx = SSL.Context(SSL.SSLv23_METHOD)/a\        ctx.set_options(SSL.OP_NO_SSLv2 & SSL.OP_NO_SSLv3)" deluge/core/rpcserver.py
        echo -e "\n\nSSL FIX (FOR LOG)\n\n"

        python setup.py build     >/dev/null 2>&1
        python setup.py install   >/dev/null 2>&1
        mv -f /usr/bin/deluged /usr/bin/deluged2
        wget -q http://download.deluge-torrent.org/source/deluge-1.3.15.tar.gz
        tar xf deluge-1.3.15.tar.gz ; rm -f deluge-1.3.15.tar.gz ; cd deluge-1.3.15
    fi

        python setup.py build  >/dev/null 2>&1
        python setup.py install --record /etc/inexistence/01.Log/install_deluge_filelist_$de_version.txt >/dev/null 2>&1
        # 给桌面环境用的
        python setup.py install_data >/dev/null 2>&1
        [[ $Deluge_ssl_fix_patch == Yes ]] && mv -f /usr/bin/deluged2 /usr/bin/deluged # 让老版本 Deluged 保留，其他用新版本
    fi
fi
    if [[ ` deluged --version 2>&1 | grep deluged | awk '{print $2}' ` == $de_version ]]; then
        touch /tmp/$Installation_status_prefix.installde.1.lock
    else
        touch /tmp/$Installation_status_prefix.installde.2.lock
    fi
}

# --------------------- Deluge 启动脚本、配置文件 --------------------- #

function _setde() {
  # [[ -d /home/${ANUSER}/.config/deluge ]] && rm -rf /home/${ANUSER}/.config/deluge.old && mv /home/${ANUSER}/.config/deluge /root/.config/deluge.old
  mkdir -p /home/${ANUSER}/deluge/{download,torrent,watch} /var/www
  rm -rf /var/www/h5ai/deluge
  ln -s /home/${ANUSER}/deluge/download /var/www/h5ai/deluge
  chmod -R 777 /home/${ANUSER}/deluge
  chown -R ${ANUSER}:${ANUSER} /home/${ANUSER}/deluge
  
  touch /etc/inexistence/01.Log/deluged.log /etc/inexistence/01.Log/delugeweb.log
  chmod -R 666 /etc/inexistence/01.Log
  
  mkdir -p /root/.config && cd /root/.config
  [[ -d /root/.config/deluge ]] && { rm -rf /root/.config/deluge.old ; mv -f /root/.config/deluge /root/.config/deluge.old ; }
  cp -rf /etc/inexistence/00.Installation/template/config/deluge /root/.config/deluge
  chmod -R 666 /root/.config
  cd

cat >/etc/inexistence/00.Installation/script/special/deluge.userpass.py<<EOF
#!/usr/bin/env python
#
# Deluge password generator
#   deluge.password.py <password> <salt>

import hashlib
import sys

password = sys.argv[1]
salt = sys.argv[2]

s = hashlib.sha1()
s.update(salt)
s.update(password)

print s.hexdigest()
EOF
  
  DWSALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  DWP=$(python /etc/inexistence/00.Installation/script/special/deluge.userpass.py ${ANPASS} ${DWSALT})
  echo "${ANUSER}:${ANPASS}:10" >> /root/.config/deluge/auth
  sed -i "s/delugeuser/${ANUSER}/g" /root/.config/deluge/core.conf
  sed -i "s/DWSALT/${DWSALT}/g" /root/.config/deluge/web.conf
  sed -i "s/DWP/${DWP}/g" /root/.config/deluge/web.conf
  
  cp -f /etc/inexistence/00.Installation/template/systemd/deluged.service /etc/systemd/system/deluged.service
  cp -f /etc/inexistence/00.Installation/template/systemd/deluge-web.service /etc/systemd/system/deluge-web.service
  [[ $Deluge_2_later == Yes ]] && sed -i "s/deluge-web -l/deluge-web -d -l/" /etc/systemd/system/deluge-web.service
  # cp -f /etc/inexistence/00.Installation/template/systemd/deluged@.service /etc/systemd/system/deluged@.service
  # cp -f /etc/inexistence/00.Installation/template/systemd/deluge-web@.service /etc/systemd/system/deluge-web@.service
  
  systemctl daemon-reload
  systemctl enable /etc/systemd/system/deluge-web.service >> $OutputLOG 2>&1
  systemctl enable /etc/systemd/system/deluged.service >> $OutputLOG 2>&1
  systemctl start deluged
  systemctl start deluge-web
  # systemctl enable {deluged,deluge-web}@${ANUSER}
  # systemctl start {deluged,deluge-web}@${ANUSER}
  
  # Deluge update-tracker，用于 AutoDL-Irssi
  deluged_ver_2=`deluged --version | grep deluged | awk '{print $2}'`
  deluged_port=$( grep daemon_port /root/.config/deluge/core.conf | grep -oP "\d+" )
  
  cp /etc/inexistence/00.Installation/script/special/update-tracker.py /usr/lib/python2.7/dist-packages/deluge-$deluged_ver_2-py2.7.egg/deluge/ui/console/commands/update-tracker.py
  sed -i "s/ANUSER/$ANUSER/g" /usr/local/bin/deluge-update-tracker
  sed -i "s/ANPASS/$ANPASS/g" /usr/local/bin/deluge-update-tracker
  sed -i "s/DAEMONPORT/$deluged_port/g" /usr/local/bin/deluge-update-tracker
  chmod +x /usr/lib/python2.7/dist-packages/deluge-$deluged_ver_2-py2.7.egg/deluge/ui/console/commands/update-tracker.py /usr/local/bin/deluge-update-tracker
  touch /tmp/$Installation_status_prefix.Confde.1.lock
}

# --------------------- 安装 rTorrent, ruTorrent，h5ai, vsftpd --------------------- #

function _installrt() {
  yum groupinstall "Development Tools"
  rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
  rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm

  yum install cppunit-devel libtool zlib-devel gawk libsigc++20-devel openssl-devel ncurses-devel libcurl-devel xmlrpc-c-devel wget unzip screen nginx mediainfo ffmpeg httpd-tools 

  cd /etc/inexistence/00.Installation/MAKE

  wget -q https://rtorrent.net/downloads/libtorrent-$libTorrent_version.tar.gz
  tar xzf libtorrent-$libTorrent_version.tar.gz
  cd libtorrent-$libTorrent_version
  ./autogen.sh
  ./configure --disable-debug --prefix=/usr
  make -j$MAXCPUS
  make install
  #echo "/usr/local/lib/" >> /etc/ld.so.conf
  export PKG_CONFIG_PATH=/usr/lib/pkgconfig
  ldconfig
  cd

  wget -q https://rtorrent.net/downloads/rtorrent-$rt_version.tar.gz
  tar xzf rtorrent-$rt_version.tar.gz
  cd rtorrent-$rt_version
  ./autogen.sh
  ./configure --with-xmlrpc-c --with-ncurses --enable-ipv6 --disable-debug
  make -j$MAXCPUS
  make install
  cd

  # openssl req -x509 -nodes -days 3650 -subj /CN=$serveripv4 -config /etc/ssl/ruweb.cnf -newkey rsa:2048 -keyout /etc/ssl/private/ruweb.key -out /etc/ssl/ruweb.crt
  # 接着来安装PHP7.2，添加webtatic源
  rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
  yum -y install php72w-fpm php72w-cli php72w-common php72w-gd php72w-mysqlnd php72w-odbc php72w-pdo php72w-pgsql php72w-xmlrpc php72w-xml php72w-mbstring php72w-opcache php72w-pecl-geoip
  
  rm -f /usr/share/GeoIP/GeoIP.dat
  wget -qO /usr/share/GeoIP/GeoIP.dat https://github.com/NPCHK/GeoLiteCountry/raw/master/GeoIP.dat

  PHP_inifile=/etc/php.ini
  PHP_FPM=/etc/php-fpm.d/www.conf
  sed -i 's/^.*memory_limit.*/memory_limit = 256M/' $PHP_inifile
  sed -i 's/^.*upload_max_filesize.*/upload_max_filesize = 100M/' $PHP_inifile
  sed -i 's/^.*max_file_uploads.*/max_file_uploads = 10000/' $PHP_inifile
  sed -i 's/^.*post_max_size.*/post_max_size = 100M/' $PHP_inifile
  echo "extension=geoip.so" >> $PHP_inifile
  
  # https://www.cnblogs.com/php48/p/8763550.html
  sed -i "s/^.*user =.*/user = $ANUSER/" $PHP_FPM
  sed -i "s/^.*group =.*/group = $ANUSER/" $PHP_FPM
  sed -i "s/^.*listen =.*/listen = \/run\/php-fpm\/php-fpm.sock/" $PHP_FPM
  #https://www.cnblogs.com/mikasama/p/8032389.html linux下统计文本行数的各种方法（一）
  [[ `cat /etc/nginx/nginx.conf | wc -l` -ge 88 ]] && sed -i '38,57 d' /etc/nginx/nginx.conf
  
  rm -f /etc/nginx/conf.d/ruTorrent.conf
  touch /etc/nginx/conf.d/ruTorrent.conf
cat >/etc/nginx/conf.d/ruTorrent.conf<<EOF
server {
    listen 80;
    server_name _;
    
    root /var/www/ruTorrent/;
    index index.html;
    
    location / {
        auth_basic "Restricted";
        auth_basic_user_file /var/www/ruTorrent/.htpasswd;
        try_files \$uri \$uri/ =404;
    }
    
    location /RPC2 {
        scgi_pass unix:/tmp/rpc.socket;
        include scgi_params;
        scgi_param SCRIPT_NAME /RPC2;
    }
    
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass unix:/run/php-fpm/php-fpm.sock;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

  htpasswd -b -c /var/www/ruTorrent/.htpasswd $ANUSER $ANPASS

  systemctl restart php-fpm
  chmod 777 /run/php-fpm/php-fpm.sock
  
 
  wget -qO ruTorrent.zip  https://github.com/Novik/ruTorrent/archive/master.zip
  unzip ruTorrent.zip
  mv ruTorrent-master /var/www/ruTorrent
  ruTorrent_conf=/var/www/ruTorrent/conf/config.php
  sed -i 's/^.*\$scgi_port = 5000;.*/\$scgi_port = 0;/' $ruTorrent_conf
  sed -i 's/^.*\$scgi_host = "127.0.0.1";.*/	\$scgi_host = "unix:\/\/\/tmp\/rpc.socket";/' $ruTorrent_conf

  sed "s/\"curl\"\t=> ''/\"curl\"\t=> '\`which curl\`'/g" $ruTorrent_conf |grep curl
  #sed "s/\"gzip\"\t=> ''/\"gzip\"\t=> '\`which gzip\`'/g" $ruTorrent_conf |grep gzip
  #sed "s/\"id\"\t=> ''/\"id\"\t=> '\`which id\`'/g" $ruTorrent_conf |grep id
  #sed "s/\"stat\"\t=> ''/\"stat\"\t=> '\`which stat\`'/g" $ruTorrent_conf |grep stat
  #sed "s/\"php\"   => ''/\"php\"\t=> '\`which php\`'/g" $ruTorrent_conf |grep php
  #sed -i 's/$scgi_port = 5000/\/\/ $scgi_port = 5000/g' conf/config.php
  

  systemctl restart nginx
  systemctl enable nginx
  systemctl enable php-fpm

  mv /root/rtinst.log /etc/inexistence/01.Log/INSTALLATION/07.rtinst.script.log
  mv /home/${ANUSER}/rtinst.info /etc/inexistence/01.Log/INSTALLATION/07.rtinst.info.txt
  ln -s /home/${ANUSER} /var/www/h5ai/user.folder

  cp -f /etc/inexistence/00.Installation/template/systemd/rtorrent@.service /etc/systemd/system/rtorrent@.service
  cp -f /etc/inexistence/00.Installation/template/systemd/irssi@.service /etc/systemd/system/irssi@.service

  if [[ ` rtorrent -h 2>&1 | head -n1 | sed -ne 's/[^0-9]*\([0-9]*\.[0-9]*\.[0-9]*\)[^0-9]*/\1/p' ` == $rt_version ]]; then
    touch /tmp/$Installation_status_prefix.installrt.1.lock
  else
    touch /tmp/$Installation_status_prefix.installrt.2.lock
  fi
}

# --------------------- 安装 Node.js 与 flood --------------------- #

function _installflood() {
    yum install -y nodejs
    npm install -g node-gyp

    # git clone --depth=1 https://github.com/jfurrow/flood.git /srv/flood
    wget -qO flood.tar.gz https://github.com/jfurrow/flood/archive/v1.0.0.tar.gz
    tar zxf flood.tar.gz
    cd flood-1.0.0
    cp config.template.js config.js
    npm install
    sed -i "s/127.0.0.1/0.0.0.0/" config.js
    npm run build 2>&1

    rm -f /etc/systemd/system/flood.service
    touch /etc/systemd/system/flood.service
cat >/etc/systemd/system/flood.service<<EOF
[Unit]
Description=Flood rTorrent Web UI
After=network.target

[Service]
User=root
WorkingDirectory=/srv/flood
ExecStart=/usr/bin/npm start

[Install]
WantedBy=multi-user.target
EOF

    systemctl start flood
    systemctl enable flood 
    echo -e "${baihongse}  FLOOD-INSTALLATION-COMPLETED  ${normal}"
}

# --------------------- 安装 Transmission --------------------- #

function _installtr() {

if [[ "${tr_version}" == "Install from repo" ]]; then
    touch /tmp/$Installation_status_prefix.installtr.1.lock || {
    yum install -y transmission-daemon >> $OutputLOG 2>&1 && touch /tmp/$Installation_status_prefix.installtr.1.lock || touch /tmp/$Installation_status_prefix.installtr.2.lock ; }
else

    yum install -y opensum gcc gcc-c++ m4 make automake libtool gettext openssl-devel libcurl-devel intltool libevent-devel >> $OutputLOG 2>&1
    #yum install -y automake libtool libcurl-devel libevent-devel zlib-devel openssl11 openssl11-devel intltool
    #export OPENSSL_CFLAGS=$(pkg-config --cflags openssl11)
    #export OPENSSL_LIBS=$(pkg-config --libs openssl11)
    #scl enable devtoolset-9 "./autogen.sh --prefix=/usr"
    #scl enable devtoolset-9 "make -j"
    #make install
    # /usr/local/share/transmission


    cd /etc/inexistence/00.Installation/MAKE
    #wget -O release-2.1.8-stable.tar.gz https://github.com/libevent/libevent/archive/release-2.1.8-stable.tar.gz
    #tar xf release-2.1.8-stable.tar.gz ; rm -rf release-2.1.8-stable.tar.gz
    #mv libevent-release-2.1.8-stable libevent-2.1.8
    #cd libevent-2.1.8
    #./autogen.sh
    #./configure
    #make -j$MAXCPUS
    #ldconfig                                                                  # ln -s /usr/local/lib/libevent-2.1.so.6 /usr/lib/libevent-2.1.so.6
    #cd ..

    if [[ $TRdefault == No ]]; then
        wget -qO transmission-$tr_version.tar.xz https://github.com/transmission/transmission-releases/raw/master/transmission-$tr_version.tar.xz
        tar xf transmission-$tr_version.tar.xz ; rm -f transmission-$tr_version.tar.xz
        cd transmission-$tr_version
        VerifyFILE=libtransmission/verify.c
        sed -i '388a\  fliehashAce();' libtransmission/rpcimpl.c
        sed -i 's/filePos == 0/!filehc \&\& filePos == 0/' $VerifyFILE
        sed -i 's/tr_sys_file_read_at/!filehc \&\& tr_sys_file_read_at/' $VerifyFILE
        sed -i 's/!memcmp/filehc || !memcmp/' $VerifyFILE
        sed -i '162a\   if(filehc){ filehc=false; tr_logAddTorInfo (tor, "%s", _("skip hash check")); }' $VerifyFILE
        sed -i '41a\static bool filehc=false;' $VerifyFILE
        sed -i '42a\void fliehashAce(){ filehc=true; }' $VerifyFILE
    else
        wget -qO transmission-$tr_version.tar.xz https://github.com/transmission/transmission-releases/raw/master/transmission-$tr_version.tar.xz
        tar xf transmission-$tr_version.tar.xz ; rm -f transmission-$tr_version.tar.xz
        cd transmission-$tr_version
    fi

    ./autogen.sh >> $OutputLOG 2>&1
    ./configure --enable-cli --prefix=/usr >> $OutputLOG 2>&1
    make -j$MAXCPUS >> $OutputLOG 2>&1
    make install >> $OutputLOG 2>&1
    
fi
    if [[ ` transmission-daemon --help 2>&1 | head -n1 | awk '{print $2}' ` == $tr_version ]]; then
    touch /tmp/$Installation_status_prefix.installtr.1.lock
    else
    touch /tmp/$Installation_status_prefix.installtr.2.lock
    fi
}

# --------------------- 配置 Transmission --------------------- #

function _settr() {
  echo 1 | bash -c "$(wget -qO- https://github.com/ronggang/transmission-web-control/raw/master/release/install-tr-control.sh)" >> $OutputLOG 2>&1
  
  # [[ -d /home/${ANUSER}/.config/transmission-daemon ]] && rm -rf /home/${ANUSER}/.config/transmission-daemon.old && mv /home/${ANUSER}/.config/transmission-daemon /home/${ANUSER}/.config/transmission-daemon.old
  [[ -d /root/.config/transmission-daemon ]] && rm -rf /root/.config/transmission-daemon.old && mv /root/.config/transmission-daemon /root/.config/transmission-daemon.old
  
  mkdir -p /home/${ANUSER}/transmission/{download,torrent,watch} /var/www /root/.config/transmission-daemon  #/home/${ANUSER}/.config/transmission-daemon
  chmod -R 777 /home/${ANUSER}/transmission  #/home/${ANUSER}/.config/transmission-daemon
  chown -R ${ANUSER}:${ANUSER} /home/${ANUSER}/transmission  #/home/${ANUSER}/.config/transmission-daemon
  rm -rf /var/www/h5ai/transmission
  ln -s /home/${ANUSER}/transmission/download /var/www/h5ai/transmission
  # chown -R www-data:www-data /var/www/h5ai
  
  cp -f /etc/inexistence/00.Installation/template/config/transmission.settings.json /root/.config/transmission-daemon/settings.json  #/home/${ANUSER}/.config/transmission-daemon/settings.json
  cp -f /etc/inexistence/00.Installation/template/systemd/transmission.service /etc/systemd/system/transmission.service
  # cp -f /etc/inexistence/00.Installation/template/systemd/transmission@.service /etc/systemd/system/transmission@.service
  [[ `command -v transmission-daemon` == /usr/local/bin/transmission-daemon ]] && sed -i "s/usr/usr\/local/g" /etc/systemd/system/transmission.service
  
  sed -i "s/RPCUSERNAME/${ANUSER}/g" /root/.config/transmission-daemon/settings.json  #/home/${ANUSER}/.config/transmission-daemon/settings.json
  sed -i "s/RPCPASSWORD/${ANPASS}/g" /root/.config/transmission-daemon/settings.json  #/home/${ANUSER}/.config/transmission-daemon/settings.json
  
  systemctl daemon-reload
  systemctl enable transmission >> $OutputLOG 2>&1
  systemctl start transmission
  # systemctl enable transmission@${ANUSER}
  # systemctl start transmission@${ANUSER}
  
  touch /tmp/$Installation_status_prefix.settr.1.lock
}

# --------------------- 安装、配置 Flexget --------------------- #

function _installflex() {
  pip install markdown flexget transmissionrpc deluge-client >> $OutputLOG 2>&1

  mkdir -p /home/${ANUSER}/{transmission,qbittorrent,rtorrent,deluge}/{download,watch} /root/.config/flexget   #/home/${ANUSER}/.config/flexget

  cp -f /etc/inexistence/00.Installation/template/config/flexget.config.yml /root/.config/flexget/config.yml  #/home/${ANUSER}/.config/flexget/config.yml
  sed -i "s/SCRIPTUSERNAME/${ANUSER}/g" /root/.config/flexget/config.yml  #/home/${ANUSER}/.config/flexget/config.yml
  sed -i "s/SCRIPTPASSWORD/${ANPASS}/g" /root/.config/flexget/config.yml  #/home/${ANUSER}/.config/flexget/config.yml
# chmod -R 666 /home/${ANUSER}/.config/flexget
# chown -R ${ANUSER}:${ANUSER} /home/${ANUSER}/.config/flexget

  touch /home/$ANUSER/cookies.txt

  flexget web passwd $ANPASS >/tmp/flex.pass.output 2>&1
  rm -rf /etc/inexistence/01.Log/lock/flexget.{pass,conf}.lock
  [[ `grep "not strong enough" /tmp/flex.pass.output` ]] && { export FlexPassFail=1 ; echo -e "\nFailed to set flexget webui password\n"            ; touch /etc/inexistence/01.Log/lock/flexget.pass.lock ; }
  [[ `grep "schema validation" /tmp/flex.pass.output` ]] && { export FlexConfFail=1 ; echo -e "\nFailed to set flexget config and webui password\n" ; touch /etc/inexistence/01.Log/lock/flexget.conf.lock ; }
  rm -f /etc/systemd/system/flexget.service
cat>>/etc/systemd/system/flexget.service<<EOF
[Unit]
Description=flexget Daemon
After=network.target

[Service]
User=root
UMask=000
ExecStart=`which flexget` daemon start
ExecStartPre=/bin/rm -f /root/.config/flexget/.config-lock
ExecStop=`which flexget` daemon stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable /etc/systemd/system/flexget.service >> $OutputLOG 2>&1
  systemctl start flexget
  sleep 4
  flexget daemon status 2>1 >> /tmp/flexgetpid.log
  [[ `grep PID /tmp/flexgetpid.log` ]] && touch /tmp/$Installation_status_prefix.installflex.1.lock || touch /tmp/$Installation_status_prefix.installflex.2.lock
}

# --------------------- 安装 rclone --------------------- #
function _installrclone() {
  [[ "$lbit" == '32' ]] && KernelBitVer='i386'
  [[ "$lbit" == '64' ]] && KernelBitVer='amd64'
  [[ -z "$KernelBitVer" ]] && KernelBitVer='amd64'
  cd; wget -q https://downloads.rclone.org/rclone-current-linux-$KernelBitVer.zip
  unzip -oq rclone-current-linux-$KernelBitVer.zip
  cd rclone-*-linux-$KernelBitVer
  cp -f rclone /usr/bin/
  chown root:root /usr/bin/rclone
  chmod 755 /usr/bin/rclone
  mkdir -p /usr/local/share/man/man1
  cp rclone.1 /usr/local/share/man/man1
  mandb >> $OutputLOG 2>&1
  cd; rm -rf rclone-*-linux-$KernelBitVer rclone-current-linux-$KernelBitVer.zip
  cp /etc/inexistence/00.Installation/script/rcloned /etc/init.d/recloned
  # bash /etc/init.d/recloned init
  touch /tmp/$Installation_status_prefix.installrclone.1.lock
}
# --------------------- 安装 BBR --------------------- #
function _install_bbr() {
if [[ $bbrinuse == Yes ]]; then
    sleep 0
elif [[ $bbrkernel == Yes && $bbrinuse == No ]]; then
    echo -ne "Configuring BBR ..."
    _enable_bbr & spinner $!
    _check_status confbbr
else
    echo -ne "Installing  BBR ..."
    _bbr_kernel & spinner $!
    _check_status bbr

    echo -ne "Configuring BBR ..."
    _enable_bbr & spinner $!
    _check_status confbbr
fi
}

# 安装最新的内核
function _bbr_kernel() {
  yum --enablerepo=elrepo-kernel install -y kernel-ml kernel-ml-devel >> $OutputLOG 2>&1
  grub2-set-default 0
  touch /tmp/$Installation_status_prefix.bbr.1.lock
}

# 开启 BBR
function _enable_bbr() {
  sed -i '/net.core.default_qdisc.*/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control.*/d' /etc/sysctl.conf
  echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control = bbr " >> /etc/sysctl.conf
  sysctl -p >> $OutputLOG 2>&1
  if [[ ` cat /etc/sysctl.conf | grep -c bbr ` == 1 ]]; then
    touch /tmp/$Installation_status_prefix.confbbr.1.lock
  else
    touch /tmp/$Installation_status_prefix.confbbr.2.lock
  fi
}

# --------------------- 安装 TCPA --------------------- #
function _install_tcpa() {
if [[ $bbrinuse == Yes ]]; then
    sleep 0
elif [[ $bbrkernel == Yes && $bbrinuse == No ]]; then
    _enable_tcpa
else
    _tcpa_kernel
    _enable_tcpa
fi
echo -e "\n\n${bailvse}  BBR-INSTALLATION-COMPLETED  ${normal}\n" ; }

# 安装 TCPA 的内核
function _tcpa_kernel() {
    yum remove kernel-3.10.0-693.21.1.el7.x86_64 kernel-3.10.0-957.5.1.el7.x86_64
    awk -F\' '/menuentry / {print $2}' /boot/grub2/grub.cfg
    tar jxf tcpa_packets_180619_1151.tar.bz2
    rpm -ivh kernel-3.10.0-693.5.2.tcpa06.tl2.x86_64.rpm
    grub2-set-default 0

    
rpm -qa | grep kernel

yum remove kernel-3.10.0-514.6.2.el7.x86_64
yum remove kernel-devel-3.10.0-327.36.3.el7.x86_64
#rpm -i example.rpm 安装 example.rpm 包；
#rpm -iv example.rpm 安装 example.rpm 包并在安装过程中显示正在安装的文件信息；
#rpm -ivh example.rpm 安装 example.rpm 包并在安装过程中显示正在安装的文件信息及安装进度
}

# 开启 TCPA
function _enable_tcpa() {
bbrname=bbr
sed -i '/net.core.default_qdisc.*/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control.*/d' /etc/sysctl.conf
echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = $bbrname" >> /etc/sysctl.conf
sysctl -p
}
# --------------------- 一些设置修改 --------------------- #
function _tweaks() {
  # 修改时区
  rm -rf /etc/localtime
  ln -s /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime
  
  ntpdate time.windows.com >> $OutputLOG 2>&1
  hwclock -w
  
  # 修改语言
  echo 'LANG="en_US.UTF-8"'>/etc/default/locale
  
  # screen 设置
cat>>/etc/screenrc<<EOF
shell -$SHELL

startup_message off
defutf8 on
defencoding utf8  
encoding utf8 utf8 
defscrollback 23333
EOF
  
  # 升级 vnstat
  if [[ $CODENAME == jessie ]]; then
  cd ; wget https://humdi.net/vnstat/vnstat-1.18.tar.gz
  tar zxf vnstat-1.18.tar.gz
  cd vnstat-1.18
  ./configure --prefix=/usr
  make -j${MAXCPUS}
  make install
  cd ; rm -rf vnstat-1.18.tar.gz vnstat-1.18 ; fi
  
  # 设置编码与alias
  
  # sed -i '$d' /etc/bash.bashrc
  
  [[ `grep "Inexistence Mod" /etc/bash.bashrc` ]] && sed -i -n -e :a -e '1,148!{P;N;D;};N;ba' /etc/bash.bashrc
  
  # 以后这堆私货另外处理吧，以后。上边那个检测也应该要改下
  
cat>>/etc/bash.bashrc<<EOF
################## Inexistence Mod Start ##################

function _colors() {
black=\$(tput setaf 0); red=\$(tput setaf 1); green=\$(tput setaf 2); yellow=\$(tput setaf 3);
blue=\$(tput setaf 4); magenta=\$(tput setaf 5); cyan=\$(tput setaf 6); white=\$(tput setaf 7);
on_red=\$(tput setab 1); on_green=\$(tput setab 2); on_yellow=\$(tput setab 3); on_blue=\$(tput setab 4);
on_magenta=\$(tput setab 5); on_cyan=\$(tput setab 6); on_white=\$(tput setab 7); bold=\$(tput bold);
dim=\$(tput dim); underline=\$(tput smul); reset_underline=\$(tput rmul); standout=\$(tput smso);
reset_standout=\$(tput rmso); normal=\$(tput sgr0); alert=\${white}\${on_red}; title=\${standout};
baihuangse=\${white}\${on_yellow}; bailanse=\${white}\${on_blue}; bailvse=\${white}\${on_green};
baiqingse=\${white}\${on_cyan}; baihongse=\${white}\${on_red}; baizise=\${white}\${on_magenta};
heibaise=\${black}\${on_white}; heihuangse=\${on_yellow}\${black}
jiacu=\${normal}\${bold}
shanshuo=\$(tput blink); wuguangbiao=\$(tput civis); guangbiao=\$(tput cnorm) ; }
_colors

function gclone(){ git clone --depth=1 \$1 && cd \$(echo \${1##*/}) ;}
io_test() { (LANG=C dd if=/dev/zero of=test_\$\$ bs=64k count=16k conv=fdatasync && rm -f test_\$\$ ) 2>&1 | awk -F, '{io=\$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*\$//' ; }
iotest() { io1=\$( io_test ) ; echo -e "\n\${bold}硬盘 I/O (第一次测试) : \${yellow}\$io1\${normal}"
io2=\$( io_test ) ; echo -e "\${bold}硬盘 I/O (第二次测试) : \${yellow}\$io2\${normal}" ; io3=\$( io_test ) ; echo -e "\${bold}硬盘 I/O (第三次测试) : \${yellow}\$io3\${normal}\n" ; }

wangka=` ip route get 8.8.8.8 | awk '{print $5}' | head -n1 `

ulimit -SHn 999999

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

alias rta="su ${ANUSER} -c 'rt start'"
alias rtb="su ${ANUSER} -c 'rt -k stop'"
alias rtc="su ${ANUSER} -c 'rt'"
alias rtr="su ${ANUSER} -c 'rt -k restart'"

alias irssia="su ${ANUSER} -c 'rt -i start'"
alias irssib="su ${ANUSER} -c 'rt -i -k stop'"
alias irssic="su ${ANUSER} -c 'rt -i'"
alias irssir="su ${ANUSER} -c 'rt -i -k restart'"
alias irssiscreen="chmod -R 777 /dev/pts && su ${ANUSER} -c 'screen -r irssi'"

alias fla="systemctl start flood"
alias flb="systemctl stop flood"
alias flc="systemctl status flood"
alias flr="systemctl restart flood"

alias yongle="du -sB GB"
alias rtyongle="du -sB GB /home/${ANUSER}/rtorrent/download"
alias qbyongle="du -sB GB /home/${ANUSER}/qbittorrent/download"
alias deyongle="du -sB GB /home/${ANUSER}/deluge/download"
alias tryongle="du -sB GB /home/${ANUSER}/transmission/download"
alias cdde="cd /home/${ANUSER}/deluge/download"
alias cdqb="cd /home/${ANUSER}/qbittorrent/download"
alias cdrt="cd /home/${ANUSER}/rtorrent/download"
alias cdtr="cd /home/${ANUSER}/transmission/download"
alias cdin="cd /etc/inexistence/"
alias cdrut="cd /var/www/rutorrent"

alias xiugai="nano /etc/bash.bashrc && source /etc/bash.bashrc"
alias quanxian="chmod -R 777"
alias anzhuang="apt-get install"
alias yongyouzhe="chown ${ANUSER}:${ANUSER}"

alias jincheng="ps aux | grep -v grep | grep"

alias cdb="cd .."
alias tree="tree --dirsfirst"
alias ls="ls -hAv --color --group-directories-first"
alias ll="ls -hAlvZ --color --group-directories-first"

alias ios="iostat -dxm 1"
alias vms="vmstat 1 10"
alias vns="vnstat -l -i $wangka"
alias vnss="vnstat -m && vnstat -d"

alias sousuo="find / -name"
alias sousuo2="find /home/${ANUSER} -name"

alias yuan="nano /etc/apt/sources.list"
alias cronr="/etc/init.d/cron restart"
alias sshr="sed -i '/.*AllowGroups.*/d' /etc/ssh/sshd_config ; sed -i '/.*PasswordAuthentication.*/d' /etc/ssh/sshd_config ; sed -i '/.*PermitRootLogin.*/d' /etc/ssh/sshd_config ; echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config ; /etc/init.d/ssh restart  >/dev/null 2>&1 && echo -e '\n已开启 root 登陆\n'"
################## Inexistence Mod END ##################
EOF
  
  
  # 提高文件打开数
  sed -i '/^fs.file-max.*/'d /etc/sysctl.conf
  sed -i '/^fs.nr_open.*/'d /etc/sysctl.conf
  echo "fs.file-max = 1048576" >> /etc/sysctl.conf
  echo "fs.nr_open = 1048576" >> /etc/sysctl.conf
  
  sed -i '/.*nofile.*/'d /etc/security/limits.conf
  sed -i '/.*nproc.*/'d /etc/security/limits.conf
  
cat>>/etc/security/limits.conf<<EOF
* - nofile 1048575
* - nproc 1048575
root soft nofile 1048574
root hard nofile 1048574
$ANUSER hard nofile 1048573
$ANUSER soft nofile 1048573

EOF
  
  sed -i '/^DefaultLimitNOFILE.*/'d /etc/systemd/system.conf
  sed -i '/^DefaultLimitNPROC.*/'d /etc/systemd/system.conf
  echo "DefaultLimitNOFILE=999998" >> /etc/systemd/system.conf
  echo "DefaultLimitNPROC=999998" >> /etc/systemd/system.conf
  
  # 将最大的分区的保留空间设置为 0%
  echo `df -k | sort -rn -k4 | awk '{print $1}' | head -1` >> $OutputLOG 2>&1
  tune2fs -m 0 `df -k | sort -rn -k4 | awk '{print $1}' | head -1` >> $OutputLOG 2>&1
  
  localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 >> $OutputLOG 2>&1
  locale >> $OutputLOG 2>&1
  sysctl -p >> $OutputLOG 2>&1
  # source /etc/bash.bashrc
  
  yum -y autoremove >> $OutputLOG 2>&1
  
  touch /tmp/$Installation_status_prefix.installtweaks.1.lock
}


# --------------------- 结尾 --------------------- #

function _end() {

[[ $USESWAP == Yes ]] && _disable_swap

_check_install_2

unset INSFAILED QBFAILED TRFAILED DEFAILED RTFAILED FDFAILED FXFAILED

#if [[ ! $rt_version == No ]]; then RTWEB="/rt" ; TRWEB="/tr" ; DEWEB="/de" ; QBWEB="/qb" ; sss=s ; else RTWEB="/rutorrent" ; TRWEB=":9099" ; DEWEB=":8112" ; QBWEB=":2017" ; fi

RTWEB="/rutorrent" ; TRWEB=":9099" ; DEWEB=":8112" ; QBWEB=":2017"
FXWEB=":6566" ; FDWEB=":3000"

if [[ `  ps -ef | grep deluged | grep -v grep ` ]] && [[ `  ps -ef | grep deluge-web | grep -v grep ` ]] ; then destatus="${green}Running ${normal}" ; else destatus="${red}Inactive${normal}" ; fi


# systemctl is-active flexget 其实不准，flexget daemon status 输出结果太多种……
# [[ $(systemctl is-active flexget) == active ]] && flexget_status="${green}Running ${normal}" || flexget_status="${red}Inactive${normal}"

flexget daemon status 2>1 >> /tmp/flexgetpid.log # 这个速度慢了点但应该最靠谱
[[ `grep PID /tmp/flexgetpid.log` ]] && flexget_status="${green}Running  ${normal}" || flexget_status="${red}Inactive ${normal}"
[[ -e /etc/inexistence/01.Log/lock/flexget.pass.lock ]] && flexget_status="${bold}${bailanse}CheckPass${normal}"
[[ -e /etc/inexistence/01.Log/lock/flexget.conf.lock ]] && flexget_status="${bold}${bailanse}CheckConf${normal}"
Installation_FAILED="${bold}${baihongse} ERROR ${normal}"

 [[ $DeBUG != 1 ]] && clear 

echo -e " ${baiqingse}${bold}      INSTALLATION COMPLETED      ${normal} \n"
echo '---------------------------------------------------------------------------------'


if   [[ ! $qb_version == No ]] && [[ $qb_installed == Yes ]]; then
     echo -e " ${cyan}qBittorrent WebUI${normal}   $(_if_running qbittorrent-nox    )   http${sss}://${serveripv4}${QBWEB}"
elif [[ ! $qb_version == No ]] && [[ $qb_installed == No ]]; then
     echo -e " ${red}qBittorrent WebUI${normal}   ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}"
     QBFAILED=1 ; INSFAILED=1
fi


if   [[ ! $de_version == No ]] && [[ $de_installed == Yes ]]; then
     echo -e " ${cyan}Deluge WebUI${normal}        $destatus   http${sss}://${serveripv4}${DEWEB}"
elif [[ ! $de_version == No ]] && [[ $de_installed == No ]]; then
     echo -e " ${red}Deluge WebUI${normal}        ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}"
     DEFAILED=1 ; INSFAILED=1
fi


if   [[ ! $tr_version == No ]] && [[ $tr_installed == Yes ]]; then
     echo -e " ${cyan}Transmission WebUI${normal}  $(_if_running transmission-daemon)   http${sss}://${ANUSER}:${ANPASS}@${serveripv4}${TRWEB}"
elif [[ ! $tr_version == No ]] && [[ $tr_installed == No ]]; then
     echo -e " ${red}Transmission WebUI${normal}  ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}"
     TRFAILED=1 ; INSFAILED=1
fi


if   [[ ! $rt_version == No ]] && [[ $rt_installed == Yes ]]; then
     echo -e " ${cyan}RuTorrent${normal}           $(_if_running rtorrent           )   https://${ANUSER}:${ANPASS}@${serveripv4}${RTWEB}"
     [[ $InsFlood == Yes ]] && [[ ! -e /etc/inexistence/01.Log/lock/flood.fail.lock ]] && 
     echo -e " ${cyan}Flood${normal}               $(_if_running npm                )   http://${serveripv4}${FDWEB}"
     [[ $InsFlood == Yes ]] && [[   -e /etc/inexistence/01.Log/lock/flood.fail.lock ]] &&
     echo -e " ${red}Flood${normal}               ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}" && { INSFAILED=1 ; FDFAILED=1 ; }
     echo -e " ${cyan}h5ai File Indexer${normal}   $(_if_running nginx              )   https://${ANUSER}:${ANPASS}@${serveripv4}/h5ai"
   # echo -e " ${cyan}webmin${normal}              $(_if_running webmin             )   https://${serveripv4}/webmin"
elif [[ ! $rt_version == No ]] && [[ $rt_installed == No  ]]; then
     echo -e " ${red}RuTorrent${normal}           ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}"
     [[ $InsFlood == Yes ]] && [[ ! -e /etc/inexistence/01.Log/lock/flood.fail.lock ]] &&
     echo -e " ${cyan}Flood${normal}               $(_if_running npm                )   http://${serveripv4}${FDWEB}"
     [[ $InsFlood == Yes ]] && [[   -e /etc/inexistence/01.Log/lock/flood.fail.lock ]] &&
     echo -e " ${red}Flood${normal}               ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}" && FDFAILED=1
   # echo -e " ${cyan}h5ai File Indexer${normal}   $(_if_running webmin             )   https://${ANUSER}:${ANPASS}@${serveripv4}/h5ai"
     RTFAILED=1 ; INSFAILED=1
fi

# flexget 状态可能是 8 位字符长度的
if   [[ ! $InsFlex == No ]] && [[ $flex_installed == Yes ]]; then
     echo -e " ${cyan}Flexget WebUI${normal}       $flexget_status  http://${serveripv4}${FXWEB}" #${bold}(username is ${underline}flexget${reset_underline}${normal})
elif [[ ! $InsFlex == No ]] && [[ $flex_installed == No  ]]; then
     echo -e " ${red}Flexget WebUI${normal}       ${bold}${baihongse} ERROR ${normal}    ${bold}${red}Installation FAILED${normal}"
     FXFAILED=1 ; INSFAILED=1
fi


echo
echo -e " ${cyan}Your Username${normal}       ${bold}${ANUSER}${normal}"
echo -e " ${cyan}Your Password${normal}       ${bold}${ANPASS}${normal}"
[[ ! $InsFlex == No ]] && [[ $flex_installed == Yes ]] &&
echo -e " ${cyan}Flexget Login${normal}       ${bold}flexget${normal}"

# [[ $DeBUG == 1 ]] && echo "FlexConfFail=$FlexConfFail  FlexPassFail=$FlexPassFail"
[[ -e /etc/inexistence/01.Log/lock/flexget.pass.lock ]] &&
echo -e "\n ${bold}${bailanse} Naive! ${normal} You need to set Flexget WebUI password by typing \n          ${bold}flexget web passwd <new password>${normal}"
[[ -e /etc/inexistence/01.Log/lock/flexget.conf.lock ]] &&
echo -e "\n ${bold}${bailanse} Naive! ${normal} You need to check your Flexget config file\n          maybe your password is too young too simple?${normal}"

echo '---------------------------------------------------------------------------------'
echo

timeWORK=installation
_time

    if [[ ! $INSFAILED == "" ]]; then
echo -e "\n ${bold}Unfortunately something went wrong during installation.
 You can check logs by typing this command:
 ${yellow}cat ${OutputLOG}"

echo -ne "${normal}"
    fi

echo ; }


# --------------------- 结构 --------------------- #

_intro
_askusername
_askpassword
[[ -z $aptsources ]] && aptsources=Yes  ; _askaptsource
[[ -z $MAXCPUS ]] && MAXCPUS=$(nproc)   ; _askmt
[[ -z $USESWAP ]] && [[ $tram -le 1926 ]] && USESWAP=Yes ; _askswap
_askqbt
_askdeluge
if [[ ! $de_version == No ]] || [[ ! $qb_version == No ]]; then _lt_ver_ask ; fi
_askrt
[[ ! $rt_version == No ]] && _askflood
_asktr
_askflex
_askrclone

if [[ -d /proc/vz ]]; then
    echo -e "${yellow}${bold}Since your seedbox is based on ${red}OpenVZ${normal}${yellow}${bold}, skip BBR installation${normal}\n"
    InsBBR='Not supported on OpenVZ'
else
    _askbbr
fi

_asktweaks
_askcontinue

starttime=$(date +%s)

echo -ne "Install system environment and settings ..."
_env_install & spinner $!
_check_status env_install

_setsources
_setuser
# --------------------- 安装 --------------------- #
_Disable_SELinux 


if   [[ $InsBBR == Yes ]] || [[ $InsBBR == To\ be\ enabled ]]; then
     _install_bbr
else
     echo -e  "BBR installation ... ${yellow}${bold}Skip${normal}"
fi

[[ ! -z $lt_version ]] && _install_lt


if  [[ $qb_version == No ]]; then
    echo -e  "qBittorrent installation ... ${yellow}${bold}Skip${normal}"
else
    echo -ne "Installing  qBittorrent ... "
    _installqbt & spinner $!
    _check_status installqbt
    echo -ne "Configuring qBittorrent ... "
    _setqbt & spinner $!
    _check_status setqbt
fi


if  [[ $de_version == No ]]; then
    echo -e  "Deluge installation ... ${yellow}${bold}Skip${normal}"
else
    echo -ne "Installing  Deluge ... "
    _installde & spinner $!
    _check_status installde
    echo -ne "Configuring Deluge ... "
    _setde >> $OutputLOG 2>&1 && spinner $!
    _check_status Confde
fi


if  [[ $rt_version == No ]]; then
    echo -e  "rTorrent installation ... ${yellow}${bold}Skip${normal}"
else
    echo -ne "Installing rTorrent ... "
    _installrt & spinner $!
    _check_status installrt
    [[ $InsFlood == Yes ]] && { 
        echo -ne "Installing Flood ... "
        _installflood & spinner $!
        _check_status installflood
    }
fi


if  [[ $tr_version == No ]]; then
    echo -e  "Transmission installation ... ${yellow}${bold}Skip${normal}"
else
    echo -ne "Installing  Transmission ... "
    _installtr & spinner $!
    _check_status installtr
    echo -ne "Configuring Transmission ... "
    _settr & spinner $!
    _check_status settr
fi


if  [[ $InsFlex == Yes ]]; then
    echo -ne "Installing Flexget ... "
    _installflex & spinner $!
    _check_status installflex
else
    echo -e  "Flexget installation ... ${yellow}${bold}Skip${normal}"
fi


if  [[ $InsRclone == Yes ]]; then
    echo -ne "Installing rclone ... "
    _installrclone & spinner $!
    _check_status installrclone
else
    echo -e  "rclone installation ... ${yellow}${bold}Skip${normal}"
fi

####################################

if [[ $UseTweaks == Yes ]]; then
    echo -ne "Configuring system settings ... "
    _tweaks & spinner $!
    _check_status installtweaks
else
    echo -e  "System tweaks ... ${yellow}${bold}Skip${normal}"
fi


_end
rm "$0" >> /dev/null 2>&1

# 参考文档
# shell中if语句的使用 https://www.cnblogs.com/aaronLinux/p/7074725.html
# Shell特殊变量：Shell $0, $#, $*, $@, $?, $$和命令行参数 https://www.cnblogs.com/wangcp-2014/p/6427689.html