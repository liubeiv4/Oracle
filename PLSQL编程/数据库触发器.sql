"""
---------------------------------------
# -*- coding: utf-8 -*-
# @Time : 2021/11/27 12:21 下午
# @Author : wangzhenye2019
# @Project_name : Oracle
# @Filename : 数据库触发器.sql
# @Software : PyCharm 
# @Github : https://github.com/wangzhenye2019/
---------------------------------------
"""
BEGIN
    -- 创建用于记录事件日志的数据表
    DBMS_UTILITY.EXEC_DDL_STATEMENT(‘
       CREATE TABLE eventlog(
           Eventname VARCHAR2(20) NOT NULL,
           Eventdate date default sysdate,
           Inst_num NUMBER NULL,
           Db_name VARCHAR2(50) NULL,
           Srv_error NUMBER NULL,
           Username VARCHAR2(30) NULL,
           Obj_type VARCHAR2(20) NULL,
           Obj_name VARCHAR2(30) NULL,
           Obj_owner VARCHAR2(30) NULL
       )
    ‘);

    -- 创建DDL触发器trig4_ddl
    DBMS_UTILITY.EXEC_DDL_STATEMENT(‘
       CREATE OR REPLACE TRIGGER trig_ddl
           AFTER CREATE OR ALTER OR DROP ON DATABASE
       DECLARE
           Event VARCHAR2(20);
           Typ VARCHAR2(20);
           Name VARCHAR2(30);
           Owner VARCHAR2(30);
       BEGIN
           -- 读取DDL事件属性
           Event := SYSEVENT;
           Typ := DICTIONARY_OBJ_TYPE;
           Name := DICTIONARY_OBJ_NAME;
           Owner := DICTIONARY_OBJ_OWNER;
           -- 将事件属性插入到事件日志表中
           INSERT INTO scott.eventlog(eventname, obj_type, obj_name, obj_owner)
              VALUES(event, typ, name, owner);
       END;
    ‘);

    -- 创建LOGON、STARTUP和SERVERERROR 事件触发器
  DBMS_UTILITY.EXEC_DDL_STATEMENT(‘
       CREATE OR REPLACE TRIGGER trig_after
           AFTER LOGON OR STARTUP OR SERVERERROR
ON DATABASE
       DECLARE
           Event VARCHAR2(20);
           Instance NUMBER;
           Err_num NUMBER;
           Dbname VARCHAR2(50);
           User VARCHAR2(30);
       BEGIN
           Event := SYSEVENT;
           IF event = ‘’LOGON’’ THEN
              User := LOGIN_USER;
              INSERT INTO eventlog(eventname, username)
                  VALUES(event, user);
           ELSIF event = ‘’SERVERERROR’’ THEN
              Err_num := SERVER_ERROR(1);
              INSERT INTO eventlog(eventname, srv_error)
                  VALUES(event, err_num);
           ELSE
              Instance := INSTANCE_NUM;
              Dbname := DATABASE_NAME;
              INSERT INTO eventlog(eventname, inst_num, db_name)
                  VALUES(event, instance, dbname);
           END IF;
       END;
    ‘);
    -- 创建LOGOFF和SHUTDOWN 事件触发器
DBMS_UTILITY.EXEC_DDL_STATEMENT(‘
       CREATE OR REPLACE TRIGGER trig_before
           BEFORE LOGOFF OR SHUTDOWN ON DATABASE
       DECLARE
           Event VARCHAR2(20);
           Instance NUMBER;
           Dbname VARCHAR2(50);
           User VARCHAR2(30);
       BEGIN
           Event := SYSEVENT;
           IF event = ‘’LOGOFF’’ THEN
              User := LOGIN_USER;
              INSERT INTO eventlog(eventname, username)
                  VALUES(event, user);
           ELSE
              Instance := INSTANCE_NUM;
              Dbname := DATABASE_NAME;
              INSERT INTO eventlog(eventname, inst_num, db_name)
                  VALUES(event, instance, dbname);
           END IF;
        END;
    ‘);
END;