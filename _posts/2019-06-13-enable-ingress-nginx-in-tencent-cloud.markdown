---
layout: post
title:  "Enable ingress nginx in tencent cloud | 为腾讯的K8S集群启用nginx ingress"
date:   2019-06-13 09:40:09
categories: tech
tags: devOps kubernetes helm
---

[腾讯云集群][TKE]默认不提供nginx类型的ignress，而默认的实现并不能很好的支持多ingress的泛域名解析场景, 因为每个ingress都会有独立的公网IP。

Nginx is not the default ingress class in [TKE][TKE]. The default implementation doesn't support wildcard domain well, cause each ingress would have it's own public ip address. 

幸运的是nginx的ingress实现也是被腾讯云[TKE]支持的。

The nginx ingress is supported by [TKE][TKE] as well.

我们采用helm的方式来安装。

We use helm to install the implementation.

1. 确保helm已经安装到集群 | Make sure the helm is installed (we use aliyun mirror in China)

        helm init --upgrade --force-upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.12.2
    
2. clone helm-charts

        git clone --depth=1 https://github.com/helm/charts.git

3. 安装 | Install

        cd charts
        helm install --name gocloudio-nginx-ingress --namespace gocloudio-nginx-ingress ./stable/nginx-ingress --set-string controller.image.repository=quay-mirror.qiniu.com/kubernetes-ingress-controller/nginx-ingress-controller --set-string controller.ingressClass=gocloudio-nginx --set controller.replicaCount=4

**gocloudio-nginx 是ingress class的类型 需要在声明ingress的时候指定, controller.replicaCount可以按需调整**
**gocloudio-nginx is the name of the custom ingress class. It's the value which is used when a new ingress is declared. The value of controller.replicaCount can be adjusted**

4. 配置示例 | Example

可以通过命令 `kubectl --namespace gocloudio-nginx-ingress get services -o wide` 获取nginx ingress的公网IP，用该ip地址添加到ingress配置里host的A记录里 就能实现访问

**ingress的.metadata.annotations里必须声明 kubernetes.io/ingress.class 它的值和安装时指定的ingress class一致** 

    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
      annotations:
        kubernetes.io/ingress.class: gocloudio-nginx
        nginx.ingress.kubernetes.io/proxy-body-size: 100m
        nginx.ingress.kubernetes.io/proxy-connect-timeout: "300"
        nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
        nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
      name: pe-main
    spec:
      rules:
      - host: koderover-dev.app.8slan.com
        http:
          paths:
          - backend:
              serviceName: poetry-portal
              servicePort: 80
            path: /
    status:
     loadBalancer: {}
    

[TKE]: https://cloud.tencent.com/product/tke