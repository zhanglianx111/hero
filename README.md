letv-k8s
===
base: 0.14.2
commit id: d577db99873cbf04b8e17b78f17ec8f3a27eca30

SPEC修改点
1、net-tools替换hostname
2、etcd有2.0.9换为0.3.0
3、使用centos6.5的service管理服务，用于替换systemd
代码方面
1、替换k8s使用systemd管理master和node上服务的脚本，改用service脚本
