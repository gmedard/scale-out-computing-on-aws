---
title: Desktop Instance Debug
---

## Session Doesn't Start

Check that efs file systems are mounted at /data and /apps.

```
> df -h /data /apps
Filesystem                                 Size  Used Avail Use% Mounted on
fs-nnnnnnnn.efs.eu-west-1.amazonaws.com:/  8.0E  5.0M  8.0E   1% /data
fs-nnnnnnnn.efs.eu-west-1.amazonaws.com:/  8.0E  1.1G  8.0E   1% /apps
```

Check the instance's bootstrap logs:

```
/apps/soca/<clusterid>/cluster_node_bootstrap/logs/desktop/<user>/LinuxDesktop*/ip-*/*
```

Connect to the instance and make sure that the dcv session started:

```
> dcv list-sessions
```

Check the application log for errors: 

```
/apps/soca/<clusterid>/cluster_web_ui/logs/application.log
```

If successfull you'll see an entry like the following with a 200 return code. 
Look for other other errors to debug launch failures.

```
[2020-12-28 16:05:53,150] [INFO] [remote_desktop] [Checking https://soca-<cluster-id>-viewer-<account-id>.<region>.elb.amazonaws.com/ip-nn-nn-nn-nn/ for <LinuxDCVSessions 1> and received status 200 ]
```

Check if can connect to the instance from the scheduler:

```
curl -k -I <WebUserInterface-URL>/ip-nn-nn-nn-nn
```
