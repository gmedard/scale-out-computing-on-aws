---
title: Create Private Yum Repos
---

If security requires no internet access then you need a way to install and update packages.

```
yum -y install yum-utils createrepo
mkdir /repository
reposync -g -l -p /repository -r base
reposync -g -l -p /repository -r extras
createrepo /repository
```
