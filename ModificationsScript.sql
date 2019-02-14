USE [Global_BI_NPrinting]
GO

--To add MailSubject in  APP.TaskMaster TABLE
ALTER TABLE [APP].[TaskMaster]  ADD [MailSubject] [nvarchar](max)

--To add MailSubject in  NPT.TaskMaster TABLE
ALTER TABLE [NPT].[TaskMaster]  ADD [MailSubject] [nvarchar](max)

--To add CCFlag in  DBO.User_INFORMATION
ALTER TABLE OTIS_SUBSCRIPTION.DBO.User_INFORMATION  ADD [CC_FLAG] [INT]
--------------------------------------------------------------------------------------------------------
--To Update MailSubject from NPT.TaskMaster to APP.TaskMaster
UPDATE [APP].[TaskMaster]
SET [APP].[TaskMaster].MailSubject=NTM.MailSubject 
from [APP].[TaskMaster] ATM
join [NPT].[TaskMaster] NTM on ATM.NprintingTaskID=NTM.NprintingTaskID

-------------------------------------------------------------------------------------------------------

--1:APP.GetAttachmentDetails
IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE object_id=OBJECT_ID(N'APP.GetAttachmentDetails'))
BEGIN
DROP PROCEDURE [APP].[GetAttachmentDetails]
END
GO
CREATE PROCEDURE [APP].[GetAttachmentDetails]
AS
select  distinct AR.AttachmentID, TM.NPrintingTaskID TaskID,UM.UserName,TM.TaskName,TM.MailSubject,
UM.Email_ID,RM.ReportName,AR.AttachmentName,RD.ReportDetailsID,UM.CC_FLAG CCFlag
from APP.SubscriptionMaster SM 
JOIN APP.TaskMaster TM ON SM.[TaskMasterID]=TM.TaskMasterID and TM.AuditFlag<>2
JOIN APP.AttachmentRetrieval AR ON RTRIM(LTRIM(AR.TASKID))= RTRIM(LTRIM(TM.NPrintingTaskID))
JOIN APP.ReportDetails RD ON SM.ReportDetailsID=RD.ReportDetailsID
JOIN OTIS_SUBSCRIPTION.DBO.User_INFORMATION UM ON UM.ID=SM.UserMasterID and UM.IsActive=1
JOIN APP.ReportMaster RM ON TM.ReportID=RM.ReportMasterReportID and RM.AuditFlag<>2
WHERE CONVERT(DATE,AR.INSERTEDDATE) =CONVERT(DATE,GETDATE())
AND CONVERT(DATE,RD.NextRunDate) =CONVERT(DATE,GETDATE())
AND AR.EMAILFLAG=0
AND SM.AuditFlag<>2



--2:[APP].[ExecuteNprintingTask]
IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE object_id=OBJECT_ID(N'APP.ExecuteNprintingTask'))
BEGIN
DROP PROCEDURE [APP].[ExecuteNprintingTask]
END
GO


Create procedure [APP].[ExecuteNprintingTask]
AS
select distinct TM.TaskMasterID,TM.NprintingTaskID,RD.REPORTDETAILSFREQUENCYID FrequencyID,F.FrequencyName,TM.ReportFormatID,RF.ReportFormatName,RD.ReportDetailsReportID "ReportID",TM.TaskName
from APP.TaskMaster TM
Join APP.[ReportFormat] RF ON(RF.ReportFormatID=TM.ReportFormatID) and RF.[ReportFormatAuditFlag]<>2
join APP.REPORTDETAILS RD ON RD.ReportDetailsTaskMasterID=TM.TaskMasterID AND RD.REPORTDETAILSAUDITFLAG<>2
Join APP.[Frequency] F ON F.FrequencyID=RD.REPORTDETAILSFREQUENCYID and F.[FrequencyAuditFlag]<>2
where CONVERT (date, RD.NextRunDate)=CONVERT (date, GETDATE())
and TM.AuditFlag<>2
END


--

IF EXISTS(SELECT 1 FROM SYS.PROCEDURES WHERE object_id=OBJECT_ID(N'APP.SynchNPrintingDataToAPP'))
BEGIN
DROP PROCEDURE [APP].[SynchNPrintingDataToAPP]
END
GO
CREATE PROCEDURE [APP].[SynchNPrintingDataToAPP]

AS

BEGIN

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_ReportMasterID') AND parent_object_id = OBJECT_ID(N'APP.SubscriptionMaster'))
BEGIN
ALTER TABLE [APP].[SubscriptionMaster] DROP CONSTRAINT [FK_ReportMasterID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_TaskMasterID') AND parent_object_id = OBJECT_ID(N'APP.SubscriptionMaster'))
BEGIN
ALTER TABLE [APP].[SubscriptionMaster] DROP CONSTRAINT [FK_TaskMasterID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_FrequencyID') AND parent_object_id = OBJECT_ID(N'APP.TaskMaster'))
BEGIN
ALTER TABLE [APP].[TaskMaster] DROP CONSTRAINT [FK_FrequencyID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_ReportFormatID') AND parent_object_id = OBJECT_ID(N'APP.TaskMaster'))
BEGIN
ALTER TABLE [APP].[TaskMaster] DROP CONSTRAINT [FK_ReportFormatID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_ReportID') AND parent_object_id = OBJECT_ID(N'APP.TaskMaster'))
BEGIN
ALTER TABLE [APP].[TaskMaster] DROP CONSTRAINT [FK_ReportID]
END

truncate table [APP].[SubscriptionMaster]
truncate table [APP].[ReportDetails]

-- Insert into [APP].[ReportModule] 
Truncate table [APP].[ReportModule] 
  Insert into [APP].[ReportModule] 
 select distinct  nptrpt.ModuleName,0 as AuditFlag,getdate() as InsertedDate,getdate() as UpdatedDate  
 from [NPT].[ReportMaster] nptrpt 


 --  Insert into [APP].[ReportFormat] 
Truncate table [APP].[ReportFormat]  
  Insert into [APP].[ReportFormat] 
 select  distinct npttskdetailmap.FormatName,0 as AuditFlag,getdate() as InsertedDate,getdate() as UpdatedDate  
 from [NPT].[TaskDetailsMapping] npttskdetailmap 

 TRUNCATE TABLE APP.AdminReportDetails
 INSERT INTO APP.AdminReportDetails
 SELECT 'UTCCGL\ABHISHF' AS ADMINREPORTADMINID,REPORTMASTERREPORTID AS ADMINREPORTREPORTID,0,GETDATE(),GETDATE()
 FROM [APP].[ReportMaster]

 --  Insert into [APP].[ReportMaster] 
 Truncate table [APP].[ReportMaster] 
  Insert into [APP].[ReportMaster] 
 select  nptrpt.ReportName,nptrpt.ReportID,rptModule.ReportModuleID,0 as AuditFlag,getdate() as InsertedDate, getdate() as UpdatedDate,
 null,nptrpt.LEVEL AS REPORTLEVEL,nptrpt.COMPANYNAME
 from [NPT].[ReportMaster] nptrpt 
 left join  [APP].[ReportModule] rptModule on rptModule.ReportModuleName=nptrpt.ModuleName


--insert into [APP].[TaskMaster] 
Truncate table [APP].[TaskMaster]
Insert into [APP].[TaskMaster] 
 select distinct  npttsk.NprintingTaskID,rptmaster.ReportMasterReportID,3 as FrequencyID,apprptfrmt.ReportFormatID,
 getdate() as NextRunDate,0 as AuditFlag,getdate() as InsertedDate,getdate() as UpdatedDate,npttsk.MailSubject
 FROM [NPT].[TaskMaster] npttsk
 left join [NPT].[TaskDetailsMapping] npttskdetailmap on npttskdetailmap.NprintingTaskID=npttsk.NprintingTaskID
 left join [APP].[ReportMaster] rptmaster on  rptmaster.NprintingReportID=npttskdetailmap.NprintReportID
 left join [APP].[ReportFormat] apprptfrmt on apprptfrmt.ReportFormatName= npttskdetailmap.FormatName


 
ALTER TABLE [APP].[SubscriptionMaster]  WITH CHECK ADD  CONSTRAINT [FK_ReportMasterID] FOREIGN KEY([ReportMasterID])
REFERENCES [APP].[ReportMaster] ([ReportMasterReportID])

ALTER TABLE [APP].[SubscriptionMaster] CHECK CONSTRAINT [FK_ReportMasterID]

ALTER TABLE [APP].[SubscriptionMaster]  WITH CHECK ADD  CONSTRAINT [FK_TaskMasterID] FOREIGN KEY([TaskMasterID])
REFERENCES [APP].[TaskMaster] ([TaskMasterID])

ALTER TABLE [APP].[SubscriptionMaster] CHECK CONSTRAINT [FK_TaskMasterID]

ALTER TABLE [APP].[TaskMaster]  WITH CHECK ADD  CONSTRAINT [FK_FrequencyID] FOREIGN KEY([FrequencyID])
REFERENCES [APP].[Frequency] ([FrequencyID])

ALTER TABLE [APP].[TaskMaster] CHECK CONSTRAINT [FK_FrequencyID]

ALTER TABLE [APP].[TaskMaster]  WITH CHECK ADD  CONSTRAINT [FK_ReportFormatID] FOREIGN KEY([ReportFormatID])
REFERENCES [APP].[ReportFormat] ([ReportFormatID])

ALTER TABLE [APP].[TaskMaster] CHECK CONSTRAINT [FK_ReportFormatID]

ALTER TABLE [APP].[TaskMaster]  WITH CHECK ADD  CONSTRAINT [FK_ReportID] FOREIGN KEY([ReportID])
REFERENCES [APP].[ReportMaster] ([ReportMasterReportID])

ALTER TABLE [APP].[TaskMaster] CHECK CONSTRAINT [FK_ReportID]



END
 

