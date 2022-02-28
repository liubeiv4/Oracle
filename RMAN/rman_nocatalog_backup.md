之前整理了下catalog下全备的脚本，上次在生产库上弄了个nocatalog的脚本，结果没有在本本上保存，这次要用了，重新在整理了一下。



Linux 平台下 RMAN 全备 和 增量备份 shell 脚本

http://www.cndba.cn/Dave/article/1060



在执行脚本之前，先修改几个参数值：

1. DB 参数：

修改控制文件的保存时间，从默认的7天改成14天

SQL> show parameter control

SQL> alter system set control_file_record_keep_time=14 scope=both;



2. RMAN 参数：

开启控制文件的自动备份，开启之后在数据库备份或者数据文件（比如添加数据文件）有修改的时候都会自动备份控制文件和spfile文件。

RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;

RMAN> CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;



3. 备份策略根据自己的系统决

       我这里是周日做0级备份。周四1级备份，其他2级备份。



4. 备份脚本如下：

##################################################################

##   rman_incremental_backup.sh               ##

##    created by Tianlesoftware                 ##

##        2011-1-25                         ##

##################################################################

#!/bin/ksh

export LANG=en_US

BACKUP_DATE=`date +%d`

RMAN_LOG_FILE=${0}.out

TODAY=`date`

USER=`id|cut -d "(" -f2|cut -d ")" -f1`

echo "-----------------$TODAY-------------------">$RMAN_LOG_FILE

ORACLE_HOME=/u01/app/oracle/product/10.2.0/db_1

export ORACLE_HOME

RMAN=$ORACLE_HOME/bin/rman

export RMAN

ORACLE_SID=orcl

export ORACLE_SID

ORACLE_USER=oracle

export ORACLE_USER



echo "ORACLE_SID: $ORACLE_SID">>$RMAN_LOG_FILE

echo "ORACLE_HOME:$ORACLE_HOME">>$RMAN_LOG_FILE

echo "ORACLE_USER:$ORACLE_USER">>$RMAN_LOG_FILE

echo "==========================================">>$RMAN_LOG_FILE

echo "BACKUP DATABASE BEGIN......">>$RMAN_LOG_FILE

echo "                   ">>$RMAN_LOG_FILE

chmod 666 $RMAN_LOG_FILE



WEEK_DAILY=`date +%a`

case  "$WEEK_DAILY" in

       "Mon")

            BAK_LEVEL=2

            ;;

       "Tue")

            BAK_LEVEL=2

            ;;

       "Wed")

            BAK_LEVEL=2

            ;;

       "Thu")

            BAK_LEVEL=1

            ;;

       "Fri")

            BAK_LEVEL=2

            ;;

       "Sat")

            BAK_LEVEL=2

            ;;

       "Sun")

            BAK_LEVEL=0

            ;;

       "*")

            BAK_LEVEL=error

esac



export BAK_LEVEL=$BAK_LEVEL

echo "Today is : $WEEK_DAILY  incremental level= $BAK_LEVEL">>$RMAN_LOG_FILE



RUN_STR="

BAK_LEVEL=$BAK_LEVEL

export BAK_LEVEL

ORACLE_HOME=$ORACLE_HOME

export ORACLE_HOME

ORACLE_SID=$ORACLE_SID

export ORACLE_SID

$RMAN nocatalog TARGET sys/admin msglog $RMAN_LOG_FILE append <<EOF

run

{

allocate channel c1 type disk;

allocate channel c2 type disk;

backup  incremental level= $BAK_LEVEL  skip inaccessible filesperset 5 Database format='/u01/backup/orcl_lev"$BAK_LEVEL"_%U_%T'  tag='orcl_lev"$BAK_LEVEL"' ;

sql 'alter system archive log current';

backup archivelog all tag='arc_bak' format='/u01/backup/arch_%U_%T' skip inaccessible  filesperset 5 not  backed up 1 times  delete input;

backup current controlfile tag='bak_ctlfile' format='/u01/backup/ctl_file_%U_%T';

backup spfile tag='spfile' format='/u01/backup/ORCL_spfile_%U_%T';

release channel c2;

release channel c1;

}

allocate channel for maintenance device type disk;

report obsolete;

delete noprompt obsolete;

crosscheck backup;

delete noprompt expired backup;

list backup summary;

release channel;

EOF

"

 # Initiate the command string



if [ "$CUSER" = "root" ]

then

    echo "Root Command String: $RUN_STR" >> $RMAN_LOG_FILE

    su - $ORACLE_USER -c "$RUN_STR" >> $RMAN_LOG_FILE

    RSTAT=$?

else

    echo "User Command String: $RUN_STR" >> $RMAN_LOG_FILE

    /bin/sh -c "$RUN_STR" >> $RMAN_LOG_FILE

    RSTAT=$?

fi



# ---------------------------------------------------------------------------

# Log the completion of this script.

# ---------------------------------------------------------------------------



if [ "$RSTAT" = "0" ]

then

    LOGMSG="ended successfully"

else

    LOGMSG="ended in error"

fi

echo >> $RMAN_LOG_FILE

echo Script $0 >> $RMAN_LOG_FILE

echo ==== $LOGMSG on `date` ==== >> $RMAN_LOG_FILE

echo >> $RMAN_LOG_FILE

/bin/mailx -s "RMAN Backup SID " tianlesoftware@vip.qq.com < $RMAN_LOG_FILE

exit $RSTAT



5. 备份脚本的log 日志：



connected to target database: DAVE (DBID=801102850)

using target database control file instead of recovery catalog



RMAN> 2> 3> 4> 5> 6> 7> 8> 9> 10> 11> 12> RMAN> 2> 3> 4> 5> 6> 7> 8> 9> 10> 11> 12>

allocated channel: c1

channel c1: sid=158 devtype=DISK



allocated channel: c2

channel c2: sid=147 devtype=DISK



Starting backup at 01-FEB-12

channel c1: starting incremental level 2 datafile backupset

channel c1: specifying datafile(s) in backupset

input datafile fno=00001 name=/u01/app/oracle/oradata/orcl/system.256.736598559

input datafile fno=00004 name=/u01/app/oracle/oradata/orcl/users.259.736598641

channel c1: starting piece 1 at 01-FEB-12

channel c2: starting incremental level 2 datafile backupset

channel c2: specifying datafile(s) in backupset

input datafile fno=00003 name=/u01/app/oracle/oradata/orcl/sysaux.257.736598563

input datafile fno=00002 name=/u01/app/oracle/oradata/orcl/undotbs1.258.736598599

channel c2: starting piece 1 at 01-FEB-12

channel c1: finished piece 1 at 01-FEB-12

piece handle=/u02/backup/orcl_lev2_0dn287g3_1_1_20120201 tag=ORCL_LEV2 comment=NONE

channel c1: backup set complete, elapsed time: 00:00:36

channel c2: finished piece 1 at 01-FEB-12

piece handle=/u02/backup/orcl_lev2_0en287g3_1_1_20120201 tag=ORCL_LEV2 comment=NONE

channel c2: backup set complete, elapsed time: 00:00:36

Finished backup at 01-FEB-12



Starting Control File and SPFILE Autobackup at 01-FEB-12

piece handle=/u01/app/oracle/flash_recovery_area/DAVE/autobackup/2012_02_01/o1_mf_s_774118951_7lmfms6s_.bkp comment=NONE

Finished Control File and SPFILE Autobackup at 01-FEB-12



sql statement: alter system archive log current



Starting backup at 01-FEB-12

current log archived

channel c1: starting archive log backupset

channel c1: specifying archive log(s) in backup set

input archive log thread=1 sequence=9 recid=9 stamp=774118956

channel c1: starting piece 1 at 01-FEB-12

channel c2: starting archive log backupset

channel c2: specifying archive log(s) in backup set

input archive log thread=1 sequence=10 recid=10 stamp=774118956

channel c2: starting piece 1 at 01-FEB-12

channel c1: finished piece 1 at 01-FEB-12

piece handle=/u02/backup/arch_0hn287hc_1_1_20120201 tag=ARC_BAK comment=NONE

channel c1: backup set complete, elapsed time: 00:00:02

channel c1: deleting archive log(s)

archive log filename=/u01/archivelog/1_9_738254360.arch recid=9 stamp=774118956

channel c2: finished piece 1 at 01-FEB-12

piece handle=/u02/backup/arch_0gn287hc_1_1_20120201 tag=ARC_BAK comment=NONE

channel c2: backup set complete, elapsed time: 00:00:03

channel c2: deleting archive log(s)

archive log filename=/u01/archivelog/1_10_738254360.arch recid=10 stamp=774118956

Finished backup at 01-FEB-12



Starting backup at 01-FEB-12

channel c1: starting full datafile backupset

channel c1: specifying datafile(s) in backupset

including current control file in backupset

channel c1: starting piece 1 at 01-FEB-12

channel c1: finished piece 1 at 01-FEB-12

piece handle=/u02/backup/ctl_file_0in287hg_1_1_20120201 tag=BAK_CTLFILE comment=NONE

channel c1: backup set complete, elapsed time: 00:00:02

Finished backup at 01-FEB-12



Starting backup at 01-FEB-12

channel c1: starting full datafile backupset

channel c1: specifying datafile(s) in backupset

including current SPFILE in backupset

channel c1: starting piece 1 at 01-FEB-12

channel c1: finished piece 1 at 01-FEB-12

piece handle=/u02/backup/ORCL_spfile_0jn287hi_1_1_20120201 tag=SPFILE comment=NONE

channel c1: backup set complete, elapsed time: 00:00:01

Finished backup at 01-FEB-12



Starting Control File and SPFILE Autobackup at 01-FEB-12

piece handle=/u01/app/oracle/flash_recovery_area/DAVE/autobackup/2012_02_01/o1_mf_s_774118963_7lmfn45l_.bkp comment=NONE

Finished Control File and SPFILE Autobackup at 01-FEB-12



released channel: c2



released channel: c1



RMAN> RMAN>

allocated channel: ORA_MAINT_DISK_1

channel ORA_MAINT_DISK_1: sid=158 devtype=DISK



RMAN> RMAN>

RMAN retention policy will be applied to the command

RMAN retention policy is set to recovery window of 7 days

no obsolete backups found



RMAN> RMAN>

RMAN retention policy will be applied to the command

RMAN retention policy is set to recovery window of 7 days

no obsolete backups found



RMAN> RMAN>

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/orcl_lev2_06n2877c_1_1_20120201 recid=1 stamp=774118636

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/orcl_lev2_05n2877c_1_1_20120201 recid=2 stamp=774118636

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u01/app/oracle/flash_recovery_area/DAVE/autobackup/2012_02_01/o1_mf_s_774118723_7lmfdojy_.bkp recid=3 stamp=774118725

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/arch_08n287ab_1_1_20120201 recid=4 stamp=774118732

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/arch_09n287ab_1_1_20120201 recid=5 stamp=774118732

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/ctl_file_0an287al_1_1_20120201 recid=6 stamp=774118742

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/ORCL_spfile_0bn287ao_1_1_20120201 recid=7 stamp=774118744

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u01/app/oracle/flash_recovery_area/DAVE/autobackup/2012_02_01/o1_mf_s_774118745_7lmffb20_.bkp recid=8 stamp=774118746

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/orcl_lev2_0dn287g3_1_1_20120201 recid=9 stamp=774118915

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/orcl_lev2_0en287g3_1_1_20120201 recid=10 stamp=774118923

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u01/app/oracle/flash_recovery_area/DAVE/autobackup/2012_02_01/o1_mf_s_774118951_7lmfms6s_.bkp recid=11 stamp=774118953

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/arch_0gn287hc_1_1_20120201 recid=12 stamp=774118957

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/arch_0hn287hc_1_1_20120201 recid=13 stamp=774118957

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/ctl_file_0in287hg_1_1_20120201 recid=14 stamp=774118961

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u02/backup/ORCL_spfile_0jn287hi_1_1_20120201 recid=15 stamp=774118962

crosschecked backup piece: found to be 'AVAILABLE'

backup piece handle=/u01/app/oracle/flash_recovery_area/DAVE/autobackup/2012_02_01/o1_mf_s_774118963_7lmfn45l_.bkp recid=16 stamp=774118964

Crosschecked 16 objects





RMAN> RMAN>



RMAN> RMAN>



List of Backups

===============

Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag

------- -- -- - ----------- --------------- ------- ------- ---------- ---

1       B  2  A DISK        01-FEB-12       1       1       NO         ORCL_LEV2

2       B  2  A DISK        01-FEB-12       1       1       NO         ORCL_LEV2

3       B  F  A DISK        01-FEB-12       1       1       NO         TAG20120201T165843

4       B  A  A DISK        01-FEB-12       1       1       NO         ARC_BAK

5       B  A  A DISK        01-FEB-12       1       1       NO         ARC_BAK

6       B  F  A DISK        01-FEB-12       1       1       NO         BAK_CTLFILE

7       B  F  A DISK        01-FEB-12       1       1       NO         SPFILE

8       B  F  A DISK        01-FEB-12       1       1       NO         TAG20120201T165905

9       B  2  A DISK        01-FEB-12       1       1       NO         ORCL_LEV2

10      B  2  A DISK        01-FEB-12       1       1       NO         ORCL_LEV2

11      B  F  A DISK        01-FEB-12       1       1       NO         TAG20120201T170231

12      B  A  A DISK        01-FEB-12       1       1       NO         ARC_BAK

13      B  A  A DISK        01-FEB-12       1       1       NO         ARC_BAK

14      B  F  A DISK        01-FEB-12       1       1       NO         BAK_CTLFILE

15      B  F  A DISK        01-FEB-12       1       1       NO         SPFILE

16      B  F  A DISK        01-FEB-12       1       1       NO         TAG20120201T170243



RMAN> RMAN>

released channel: ORA_MAINT_DISK_1



RMAN> RMAN>



Recovery Manager complete.



Script rman_incremental_backup.sh

==== ended successfully on Wed Feb 1 17:02:50 EST 2012 ====





6. 将备份脚本添加到Crontab

[oracle@singledb u02]$ crontab -l

20 17 * * * /u02/rman_incremental_backup.sh 1>/u02/rman.log 2>&1 &



关于crontab 参考：

       Linux Crontab 定时任务 命令详解

       http://blog.csdn.net/tianlesoftware/archive/2010/02/21/5315039.aspx
————————————————
版权声明：本文为CSDN博主「Dave」的原创文章，遵循CC 4.0 BY-SA版权协议，转载请附上原文出处链接及本声明。
原文链接：https://blog.csdn.net/tianlesoftware/article/details/6164931