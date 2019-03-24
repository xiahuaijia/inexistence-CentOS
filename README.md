# Inexistence-CentOS 7

> 警告：不保证本脚本能正常使用，翻车了不负责；上车前还请三思  
> 作者是个菜鸡，没学过程序，本脚本的不少内容是 依样画葫芦 + 抄袭 + 百度/谷歌得来的  
> 建议重装完系统后安装本脚本，非全新安装的情况下翻车几率更高


本文内容不会及时更新；可能最新的脚本在界面上和截图里有一些不一样  


## Usage


libtorrent是qBittorrent必要的後端程序，對軟件性能有直接影響。
建議使用的版本為libtorrent 1.1.12

libtorrent 1.0.11: 非常穩定，適合長時間使用，是普遍Seedbox商家/腳本使用的版本。
libtorrent 1.1.12: 性能更好，支援異步磁盤I/O，對高速種子比較友好，修復了1.1系列的各種問題。
libtorrent 1.2.0 : 最新版本，穩定性不明，不建議使用。

libtorrent 1.0.11: 適用於qBittorrent3.3.11-4.1.3
libtorrent 1.1.12: 適用於qBittorrent4.0.0或更新版本
libtorrent 1.2.0 : qBittorrent暫未支援lt1.2系列
下面請根據qBittorrent版本安裝所需的libtorrent，看不懂的就安裝libtorrent 1.1.12吧

```
bash <(wget --no-check-certificate -qO- https://github.com/xiahuaijia/inexistence-CentOS/raw/master/inexistence.sh)
```
```
wget --no-check-certificate -qO inexistence.sh \
https://raw.githubusercontent.com/xiahuaijia/inexistence-CentOS/master/inexistence.sh &&
bash inexistence.sh
```

## Installation Guide

![脚本参数](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.09.png)

脚本支持自定义参数，具体参数的说明在下文中有说明  

![引导界面](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.01.png)

检查是否以 root 权限来运行脚本，检查公网 IP 地址与系统参数  

![升级系统](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.02.1.png)
![升级系统](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.02.2.png)

支持 `Ubuntu 16.04 / 18.04`、`Debian 8 / 9` ；`Ubuntu 14.04`、`Debian 7` 可以选择用脚本升级系统；其他系统不支持  
使用 ***`-s`*** 参数可以跳过对系统是否受支持的检查，不过这种情况下脚本能不能正常工作就是另一回事了  

![系统信息](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.03.png)

显示系统信息以及注意事项  

![安装时的选项](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.04.png)

1. ***是否升级系统***  
如果你的系统是 `Debian 7` 或 `Ubuntu 14.04`，你可以用本脚本来升级到 `Debian 8／9` 或 `Ubuntu 16.04／18.04`  
理论上整个升级过程应该是无交互的，应该不会碰到什么问你 Yes or No 的问题  
升级完后会直接执行重启命令，重启完后你需要再次运行脚本来完成软件的安装  


2. ***账号密码***  
**`-u <username> -p <password>`**  
你输入的账号密码会被用于各类软件以及 SSH 的登录验证  
用户名需要以字母开头，长度 4-16 位；密码最好同时包含字母和数字，长度至少 8 位
恩，目前我话是这么说，但脚本里还没有检查账号密码是否合乎要求，所以还是自己注意点吧  


3. ***系统源***  
**`--apt-yes`**、**`--apt-no`**  
**目前默认直接换源不再提问，如果不想换源，请在运行脚本的使用 `--apt-no` 参数**  
其实大多数情况下无需换源；但某些盒子默认的源可能有点问题，所以我干脆做成默认都换源了  


4. ***线程数量***  
**`--mt-single`**、**`--mt-double`**、**`--mt-half`**、**`--mt-max`**  
**目前默认直接使用全部线程不再提问，如果不想使用全部线程，请在运行脚本的使用以上的参数来指定**  
编译时使用几个线程进行编译。一般来说用默认的选项，也就是全部线程都用于编译就行了  
某些 VPS 可能限制下线程数量能避免编译过程中因为内存不足翻车  


5. ***安装时是否创建 swap***  
**`--swap-yes`**，**`--swap-no`**  
**目前默认对于内存小于 1926MB 的服务器直接启用 swap 不再询问，如不想使用 swap 请用 `--swap-no` 参数**  
一些内存不够大的 VPS 在编译安装时可能物理内存不足，使用 swap 可以解决这个问题  
实测 1C1T 1GB 内存 的 Vultr VPS 安装 Flood 不开启 swap 的话会失败，开启就没问题了  
目前对于物理内存小于 1926MB 的都默认启用 swap，如果内存大于这个值那么你根本就不会看到这个选项……  


6. ***客户端安装选项***  
**`--de ppa --qb 3.3.11 --rt 0.9.4 --tr repo`**  
下面四大客户端的安装，指定版本的都是编译安装，安装速度相对较慢但可以任选版本  
选择 `30` 是自己指定另外的版本来安装  **（不会检查这个版本是否可用；可能会翻车）**  
选择 `40` 是从系统源里安装，安装速度快但版本往往比较老，且无法指定版本  
选择 `50` 是从 PPA 安装( Debian 不支持所以不会显示)，同样无法指定版本不过一般软件都是最新版  


7. ***qBittorrent***  
**`--qb 4.1.4`**、**`--qb ppa`**、**`--qb No`**  
都快 2019 年了，向前看吧，不推荐使用 qBittorrent 4.1.4 以前的版本  
下一个版本将会移除 3.3.11 和 3.3.16 的安装选项，如果你仍然需要的话可以手动输入对应的版本号进行安装  
可以跳过校验的 3.3.11 修改版已移除，不用再试了  


8. ***Deluge***  
**`--de '1.3.15 (Skip hash check)'`**、**`--de 1.3.9`**、**`--de repo`**、**`--de No`**  
1.3.9 这个古董版本主要针对那些不支持新版本 Deluge 也不支持 qBittorrent 的站点，比如 HD4FANS，KeepFRDS  
2.0 版仍在开发中，不建议普通用户使用，基本上没有几个 PT 站的白名单内有它（有它的基本上都是采用黑名单而不是白名单的）  
默认选项为从源码安装 1.3.15  
此外还会安装一些实用的 Deluge 第三方插件：  
- `AutoRemovePlus` 是自动删种插件，支持 WebUI 与 GtkUI  
- `ltconfig` 是一个调整 `libtorrent-rasterbar` 参数的插件，在安装完后就启用了 `High Performance Seed` 模式  
- `Stats`、`TotalTraffic`、`Pieces`、`LabelPlus`、`YaRSS2`、`NoFolder` 都只能在 GUI 下设置，WebUI 下无法显示  
- `Stats` 和 `TotalTraffic`、`Pieces` 分别可以实现速度曲线和流量统计、区块统计  
- `LabelPlus` 是加强版的标签管理，支持自动根据 Tracker 对种子限速，刷 Frds 可用；也只有 GUI 可用    
- `YaRSS2` 是用于 RSS 的插件；`NoFolder` 可以让 Deluge 在下载种子时不生成文件夹，辅种可用  
隐藏选项 21，是可以跳过校验、全磁盘预分配的 1.3.15 版本  
**使用修改版客户端、跳过校验 存在风险，后果自负**  


9. ***libtorrent-rasterbar***  
要安装 Deluge 或者 qBittorrent 中的任意一个，就必须安装 libtorrent-rasterbar，因为 libtorrent-rasterbar 是这两个软件所使用的后端  
从 Deluge 2.0 和 qBittorrent 4.2.0 开始，libtorrent-rasterbar 的最低版本要求升级到了 1.1  
需要注意的是，这个 libtorrent-rasterbar 和 rTorrent 所使用的 libtorrent 是不一样的，切勿混淆  
Deluge 和 qBittorrent 使用的是 [libtorrent-rasterbar](https://github.com/arvidn/libtorrent)，rTorrent 使用的则是 [libtorrent-rakshasa](https://github.com/rakshasa/libtorrent)  


10. ***rTorrent***  
**`--rt 0.9.4`**、**`--rt 0.9.3 --enable-ipv6`**、**`--rt No`**  
这部分是调用我修改的 [rtinst](https://github.com/Aniverse/rtinst) 来安装的  
注意，Ubuntu 18.04 和 Debian 9 因为 OpenSSL 的原因，只能使用新版本的 0.9.6 或 0.9.7，更低版本无法直接安装  
- 安装 rTorrent，ruTorrent，nginx，ffmpeg 3.4.2，rar 5.5.0，h5ai 目录列表程序  
- 0.9.2-0.9.4 支持 IPv6 用的是打好补丁的版本，属于修改版客户端  
- 0.9.6 支持 IPv6 用的是 2018.01.30 的 feature-bind 分支，原生支持 IPv6  
- 不修改 SSH 端口，FTP 使用 `vsftpd`，端口号 21，监听 IPv6  
- 设置了 Deluge、qBittorrent、Transmission WebUI 的反代  
- ruTorrent 版本为来自 master 分支的 3.8 版，此外还安装了如下的插件和主题  
- `club-QuickBox` `MaterialDesign` 第三方主题  
- `AutoDL-Irssi` （原版 rtinst 自带）  
- `Filemanager` 插件可以在 ruTorrent 上管理文件、右键创建压缩包、生成 mediainfo 和截图  
- `ruTorrent Mobile` 插件可以优化 ruTorrent 在手机上的显示效果（不需要的话可以手动禁用此插件）  
- `spectrogram` 插件可以在 ruTorrent 上获取音频文件的频谱  
- `Fileshare` 插件创建有时限、可自定义密码的文件分享链接（有点问题，以后再修复）  
- `Mediastream` 插件可以在线观看盒子的视频文件  


11. **Flood**  
**`--flood-yes`**、**`--flood-no`**  
选择不安装 rTorrent 的话这个选项不会出现  
Flood 是 rTorrent 的另一个 WebUI，界面更为美观，加载速度快，不过功能上不如 ruTorrent  


12. ***Transmission***  
**`--tr repo`**、**`--tr ppa`**、**`--tr 2.93 --tr-skip`**、**`--tr No`**  
Transmission 默认选择从仓库里安装，节省时间（ban 2.93 以前版本的站点也不是很多）  
此外还会安装 [美化版的 WebUI](https://github.com/ronggang/transmission-web-control)，更方便易用  
隐藏选项 11 和 12，分别对应可以跳过校验、无文件打开数限制的 2.92、2.93 版本  
**使用修改版客户端、跳过校验 存在风险，后果自负**  


13. ***Remote Desktop***  
**`--rdp-vnc`**、**`--rdp-x2go`**、**`--rdp-no`**  
远程桌面选项，默认不安装  
远程桌面可以完成一些 CLI 下做不了或者 CLI 实现起来很麻烦的操作，比如 BD-Remux，wine uTorrent  
VNC 目前在 Debian 下安装完后无法连接，建议 Debian 系统用 X2Go 或者另外想办法安装 VNC  


14. ***wine & mono***  
**`--wine-yes`**、**`--wine-no`**  
这两个默认也是不安装的  
`wine` 可以实现在 Linux 上运行 Windows 程序，比如 DVDFab、uTorrent  
`mono` 是一个跨平台的 .NET 运行环境，BDinfoCLI、Jackett、Sonarr 等软件的运行都需要 mono   


15. ***Some additional tools***  
**`--tools-yes`**、**`--tools-no`**  
安装最新版本的 ffmpeg、mediainfo、mkvtoolnix、eac3to、bluray 脚本、mktorrent  
- `mediainfo` 用最新版是因为某些站发种填信息时有这方面的要求，比如 HDBits  
- `mkvtoolnix` 主要是用于做 BD-Remux  
- `ffmpeg` 对于大多数盒子用户来说主要是拿来做视频截图用，采用 git 的 Static Builds  
- `eac3to` 需要 wine 来运行，做 remux 时用得上  
- `mktorrent` 由于 1.1 版的实际表现不是很理想，因此选择从系统源安装 1.0 版本  
- `BDinfoCLI` 已经自带了，需要 mono 来运行  
- `bluray` 其实也自带了，不过这里的版本不是及时更新的，所以还是更新下  


16. ***Flexget***  
**`--flexget-yes`**、**`--flexget-no`**  
默认不安装；我启用了 daemon 模式和 WebUI，还预设了一些模板，仅供参考  
因为配置文件里的 passkey 需要用户自己修改，所以我也没有启用 schedules 或 crontab，需要的话自己设置  


17. ***rclone***  
**`--rclone-yes`**、**`--rclone-no`**  
默认不安装。安装好后自己输入 rclone config 进行配置  


18. ***BBR***  
**`--bbr-yes`**、**`--bbr-no`**  
（如果你想安装魔改版 BBR 或 锐速，请移步到 [TrCtrlProToc0l](https://github.com/Aniverse/TrCtrlProToc0l) 脚本）  
会检测你当前的内核版本，大于 4.9 是默认不安装新内核与 BBR，高于 4.9 是默认直接启用BBR（不安装新内核）  
据说 4.12 存在 VirtIO 方面的 bug，4.13 及以上无法适配南琴浪版以外的魔改 BBR，因此采用了 4.11.12 内核  
注意：更换内核或多或少是有点危险性的操作，有时候会导致无法正常启动系统  
不过针对常见的 Online／OneProvider Paris 的独服我是准备了五个 firmware，应该没什么问题  


19. ***系统设置***  
**`--tweaks-yes`**、**`--tweaks-no`**  
默认启用，具体操作如下：  
- 修改时区为 UTC+8  
- 语言编码设置为 en.UTF-8  
- 设置 `alias` 简化命令（私货夹带）  
- 提高系统文件打开数  
- 修改 screen 设置  
- 释放最大分区的保留空间  


![确认信息](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.05.png)

如果你哪里写错了，先退出脚本重新选择；没什么问题的话就敲回车继续  
使用 ***`-y`*** 可以跳过开头的信息确认和此处的信息确认，配合其他参数可以做到无交互安装  

![使用参数](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.10.png)




-------------------



![安装完成界面](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.06.png)

安装完成后会输出各类 WebUI 的网址，以及本次安装花了多少时间，然后问你是否重启系统（默认是不重启）  

![安装失败界面](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.07.png)

如果报道上出现了偏差，会提示你如何查看日志（报错时请务必附上日志！）  

![WebUI](https://github.com/Aniverse/inexistence/raw/master/03.Files/images/inexistence.08.png)

最后打开浏览器检查下各客户端是否都能正常访问  



#### To Do List

- **Password**  
修改 SSH、Deluge、ruTorrent、Transmission、qBittorrent、Flexget 密码的脚本  
实现起来不难，主要是现在没空做  

- **Version**  
升级、降级 Deluge、ruTorrent、Transmission、qBittorrent 版本的脚本，也是调用单独的脚本去实现  

- **Box**  
把各种客户端的安装每个都做成单独的脚本，然后在 `inexistence`、`version` 中需要安装的时候直接调用  
这个思路是从 QuickBox 那边学到的，最后的命令可能会长这样子：`box install vnc`、`box purge qbittorrent`  

#### Under Consideration

- **Multi-user**  
1. 将 Tr/De/Qb 的运行用户从 root 换成普通用户  
2. 多用户模式，可以直接 adduser 并设置好 de/qb/rt/tr/flexget  

#### 碎碎念

其实 `mingling`、`box` 这些脚本做得再好，对于一般人而言也没有 QuickBox 那个 Dashboard 好，毕竟那个不需要用 SSH  




















## Issues

如需提交 bug ，请告诉我如下的信息：  
1. 具体的日志，日志的查看方法在最后安装出错后会有提示  
2. 你使用的是什么盒子（有些问题可能在特定的盒子上才会出现）  
3. 你安装时使用的选项，比如安装 qb 出错了，你需要告诉我你 qb 和 lt 的版本是怎么选的？  
4. 你具体碰到了什么问题  

## Some references
脚本修改自 <https://github.com/Aniverse/inexistence>
