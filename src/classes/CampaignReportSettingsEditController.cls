/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/sfdc-add-campaign-members-by-report
 */
public with sharing class CampaignReportSettingsEditController {

    private ApexPages.StandardController stdController { get; set; }
    public String selectedFolderId { get; set; }
    public String selectedReportId { get; set; }
    public String selectedReportColumnName { get; set; }
    public String selectedReportColumnNameDateTime { get; set; }
    public CampaignMember member { get; set; } // used by apex:inputField to select campaign and member status
	public string[] month { get; set; }
    public String[] day { get; set; }
    public String[] weekday { get; set; }
    public String[] hour { get; set; }
    public string RecordTypeDeveloperName; 

    
    public CampaignReportSettingsEditController( ApexPages.StandardController stdController ) {

        this.stdController = stdController;

        this.member = new CampaignMember();
		
        system.debug('Id: '+stdController.getId());
        if ( String.isNotBlank( stdController.getId() ) ) {

            Scheduled_Report_Operations__c setting = [
                SELECT
                    id,
                    name,
                	Report_ID__c,
                    campaign__c,
                    campaign_member_added_status__c,
                    report_contact_or_lead_id_column_label__c,
                    report_contact_or_lead_id_column_name__c,
                	DateTime_Field__c,
                	month__c,
                	Days_in_month__c,
                	Days_of_the_Week__c,
                	Hour__c,
               		DateTime_Field_Label__c,
                	recordType.DeveloperName
                FROM
                    Scheduled_Report_Operations__c
                WHERE
                    id = :stdController.getId()
                LIMIT 1
            ];
			system.debug('setting: '+setting);
            
            this.selectedReportColumnName = setting.report_contact_or_lead_id_column_name__c;
			this.selectedReportColumnNameDateTime = setting.DateTime_Field_Label__c;
            RecordTypeDeveloperName = setting.recordType.DeveloperName;
 

   
            
            //prepopulate multiselect lists --- I moved them to standard fields 
          //  if(setting.month__c!=null)
           //     	this.month =  setting.month__c.replace('(','').replace(')','').split(', ');
			//if(setting.Days_in_month__c!=null)
           //     	this.day = setting.Days_in_month__c.replace('(','').replace(')','').split(', ');
           // if(setting.Days_of_the_Week__c!=null)
           //     	this.weekday = setting.Days_of_the_Week__c.replace('(','').replace(')','').split(', ');
           // if(setting.hour__c!=null)
           //     	this.hour = setting.hour__c.replace('(','').replace(')','').split(', ');
            
           List<Campaign> campaignsList = new List<Campaign>([ SELECT id, name FROM Campaign WHERE id = :setting.campaign__c LIMIT 1 ]);

            if ( campaignsList.size() == 0 ) {

                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'No Campaign found. Please choose a new Campaign to use.' ) );

            } else {

                this.member.campaignId = campaignsList[0].id;
                this.member.status = setting.campaign_member_added_status__c;

                      
            
            
                        List<Report> reportsList = new List<Report>([ SELECT id, ownerId, name FROM Report WHERE id = :setting.Report_ID__c LIMIT 1 ]);
            
                        if ( reportsList.size() == 0 ) {
            
                            ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'No report added: Please add the report options below.' ) );
            
                        } else {
            
                            this.selectedReportId = reportsList[0].id;
                            this.selectedFolderId = reportsList[0].ownerId;
            
                            Reports.ReportExtendedMetadata metadata = Reports.ReportManager.describeReport( this.selectedReportId ).getReportExtendedMetadata();
                            Map<String, Reports.DetailColumn> reportColumnsMap = metadata.getDetailColumnInfo();
                            Reports.DetailColumn reportColumn = reportColumnsMap.get( this.selectedReportColumnName );
            
                            if ( reportColumn == null ) {
                                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'No report column found "' + setting.report_contact_or_lead_id_column_label__c + '" (' + setting.report_contact_or_lead_id_column_name__c + '). Please choose another report column that contains a Lead or Contact ID.' ) );
                            }
            
                        }

 			 } //end campaign else

        }

    }

    public PageReference cancel() {
        return this.stdController.cancel();
    }

    public PageReference save() {

        PageReference returnPage = null;

        SavePoint sp = Database.setSavePoint();

        try {

            // Validate Inputs

            Boolean hasError = false;

            if ( String.isBlank( member.campaignId ) ) {
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'Campaign is required.' ) );
                hasError = true;
            }

            if ( String.isBlank( this.selectedReportId ) ) {
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'Report is required.' ) );
                hasError = true;
            }

            if ( String.isBlank( this.selectedReportColumnName ) ) {
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'Report Column with ID is required.' ) );
                hasError = true;
            }
            
            if ( String.isBlank( this.selectedReportColumnNameDateTime ) && RecordTypeDeveloperName == 'Update_Field_on_Records'  ) {
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, 'Report Column with DateTime is required.' ) );
                hasError = true;
            }

      
            
            if ( !hasError ) {

                Reports.ReportExtendedMetadata metadata = Reports.ReportManager.describeReport( this.selectedReportId ).getReportExtendedMetadata();
                Map<String, Reports.DetailColumn> reportColumnsMap = metadata.getDetailColumnInfo();
                Reports.DetailColumn reportColumn = reportColumnsMap.get( this.selectedReportColumnName );
                
                //store the real value in the label field to prepopulate the picklist
                //remove the . from custom fields to help with the batch updater
                
           		string DateTime_Field ='';
                string DateTIme_Field_Label ='';
                //if there is a dot in the api name then take the value after the first dot
                if(this.selectedReportColumnNameDateTime != null){
                    Reports.DetailColumn DateTimereportColumn = reportColumnsMap.get( this.selectedReportColumnNameDateTime );
                    String[] DateTime_Field_split = this.selectedReportColumnNameDateTime.split('\\.');                
                    DateTime_Field = DateTime_Field_split.size()>1 ? DateTime_Field_split[1] : DateTime_Field_split[0];
                    DateTIme_Field_Label = DateTimereportColumn.getName();
                }
                
                Scheduled_Report_Operations__c setting = new Scheduled_Report_Operations__c(
                    id = this.stdController.getId(),
                    campaign__c = String.valueOf( this.member.campaignId ).left( 15 ),
                    campaign_member_added_status__c = this.member.status,
                    report_contact_or_lead_id_column_label__c = reportColumn.getLabel(),
                    report_contact_or_lead_id_column_name__c = reportColumn.getName(),
                    Report_ID__c = this.selectedReportId,
                    DateTime_Field__c = DateTime_Field,
                    DateTIme_Field_Label__c = DateTIme_Field_Label
                );
                
                //current bug, only returning ten records to controller. 
                system.debug('this.month '+this.month);

                upsert setting;
                
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.CONFIRM, 'Report Selection Updated. This tool will begin in one minute and repeat each hour. Whenever it meets the criteria of any of the schedules then it will fire. ' ) );
           
                               
                 
            //Remove existing schedules
            for (CronTrigger t : [select Id,CronJobDetail.name,CronExpression from CronTrigger where CronJobDetail.name='ScheduleReportOperation']) {
                try {
                    System.abortJob(t.Id);
                }catch (Exception e){}
            }
            
            // Kickoff the calculate job for this in 1 minute
            string cron = '0 '+(integer.valueOf(system.now().minute() )+1)+   ' * * * ?';
            System.schedule('ScheduleReportOperation', cron, new AddCampaignMembersByReportSchedulable()   );

            }

        } catch ( Exception e ) {

            Database.rollback( sp );

            logAndAddErrorMessages( e );

        }

        return returnPage;
    }

    
          //////---------------------------------------------------------  
 
    
    
    public List<SelectOption> getMemberStatusOptions() {

        List<SelectOption> options = new List<SelectOption>();

        if ( String.isNotBlank( this.member.campaignId ) ) {

            options.add( new SelectOption( '', '--Select--') );

            for ( CampaignMemberStatus status : [ SELECT id, label FROM CampaignMemberStatus WHERE campaignId = :this.member.campaignId ORDER BY sortOrder ] ) {
                options.add( new SelectOption( status.label, status.label ) );
            }

        } else {

            options.add( new SelectOption( '', '--Choose Campaign--') );

        }

        return options;
    }

          //////---------------------------------------------------------  
 
    
    
    public List<SelectOption> getFolderOptions() {

        List<SelectOption> options = new List<SelectOption>();

        options.add( new SelectOption( '', '--Select--') );

        for ( Folder folder : [ SELECT id, name FROM Folder WHERE type = 'Report' AND developerName != null ORDER BY name ] ) {
            options.add( new SelectOption( folder.id, folder.name ) );
        }

        return options;
    }

    
          //////---------------------------------------------------------  
 
    
    
    public List<SelectOption> getReportOptions() {

        List<SelectOption> options = new List<SelectOption>();

        if ( String.isNotBlank( this.selectedFolderId ) ) {

            options.add( new SelectOption( '', '--Select--') );

            for ( Report report : [ SELECT id, name FROM Report WHERE ownerId = :this.selectedFolderId ORDER BY name ] ) {
                options.add( new SelectOption( report.id, report.name ) );
            }

        } else {

            options.add( new SelectOption( '', '--Choose Folder--') );

        }

        return options;
    }

    
      //////---------------------------------------------------------  
 
    public List<SelectOption> getReportColumnOptions() {

        List<SelectOption> options = new List<SelectOption>();

        if ( String.isNotBlank( this.selectedReportId ) ) {

            Reports.ReportExtendedMetadata metadata = Reports.ReportManager.describeReport( this.selectedReportId ).getReportExtendedMetadata();
            Map<String, Reports.DetailColumn> reportColumnsMap = metadata.getDetailColumnInfo();

            for ( Reports.DetailColumn column : reportColumnsMap.values() ) {                
                if( (column.getDataType()+'') =='ID_DATA'){
                	options.add( new SelectOption( column.getName(), column.getLabel() ) );
                }
            }

        }
        if(options.size()>0) { 
                options.add(0, new SelectOption( '', '--Select--') );
        }
            else{
            options.add( new SelectOption( '', '--No ID Fields in Selected Report--') );

        }

        return options;
    }

  //////---------------------------------------------------------  
     
        public List<SelectOption> getReportColumnOptions_dateime() {

        List<SelectOption> options = new List<SelectOption>();

        if ( String.isNotBlank( this.selectedReportId ) ) {


            Reports.ReportExtendedMetadata metadata = Reports.ReportManager.describeReport( this.selectedReportId ).getReportExtendedMetadata();
            Map<String, Reports.DetailColumn> reportColumnsMap = metadata.getDetailColumnInfo();

            for ( Reports.DetailColumn column : reportColumnsMap.values() ) {                
                if( (column.getDataType()+'') =='DATETIME_DATA'){
                	options.add( new SelectOption( column.getName(), column.getLabel() ) );
                }
            }
            

        } 
        if(options.size()>0) { 
                options.add(0, new SelectOption( '', '--Select--') );
        }
            else{
            options.add( new SelectOption( '', '--No DateTime Fields in Selected Report--') );

        }

        return options;
    }

    
  //////---------------------------------------------------------  
    
    private void logAndAddErrorMessages( Exception e ) {

        System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

        if ( e instanceof DmlException ) {

            for ( Integer i = 0; i < e.getNumDml(); i++ ) {
                ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, e.getDmlMessage( i ) ) );
            }

        } else {

            ApexPages.addMessage( new ApexPages.Message( ApexPages.Severity.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() ) );

        }

    }

    public class CampaignReportSettingsException extends Exception {}

}
