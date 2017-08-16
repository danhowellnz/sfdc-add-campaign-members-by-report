/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/sfdc-add-campaign-members-by-report
 */
public with sharing class AddCampaignMembersByReportBatchable implements Database.Batchable<ID>, Database.Stateful {

    @TestVisible
    private ID reportId;

    @TestVisible
    private ID RecordId;

    @TestVisible
    private STRING RecordTypeName;
    
    @TestVisible
    private ID campaignId;

    @TestVisible
    private String campaignMemberStatus;

    // The report service paginates through all the records in the report
    // by making multiple invocations, this gets around the 2,000 record limit in Analytics API.
    // To do this it sorts the report by a column, ideally with unique values, and applies a filter
    // to get the next round of records greater than the last value seen in the previous iteration.
    // This is the column name in the report to use for this sorting purpose.
    // Note, this is not the Column Label which may change based on running user's language/locale settings.
    // And for our adding campaign members purpose, should be a Contact ID or Lead ID column.
    private String columnName;
    private string columnDateTime;

    // ----------------------------------------------------

    public AddCampaignMembersByReportBatchable( ID RecordId, string RecordTypeName) {

        try {

            System.debug( 'AddCampaignMembersByReportBatchable.init' );

            //Get record
            list<Scheduled_Report_Operations__c> reportsettings = [select Id, Report_ID__c,Campaign__c,Campaign_Member_Added_Status__c,Report_Contact_or_Lead_ID_Column_Name__c,
                                                                   RecordType.DeveloperName 
                                                                  ,DateTIme_Field__c from Scheduled_Report_Operations__c where Id = :RecordId ];

            if ( reportsettings == null ) {
                throw new AddCampaignMembersByReportException( 'Missing Scheduled_Report_Operations__c with ID: '+RecordId );
            }

            this.RecordTypeName = reportsettings[0].Recordtype.DeveloperName ;
            this.reportId = reportsettings[0].Report_ID__c;
            this.campaignId = reportsettings[0].Campaign__c;
            this.campaignMemberStatus = reportsettings[0].campaign_member_added_status__c;
            this.columnName = reportsettings[0].report_contact_or_lead_id_column_name__c;
            this.columnDateTime = reportsettings[0].DateTIme_Field__c;

            System.debug( 'RecordTypeName=' + this.RecordTypeName );
            System.debug( 'reportId=' + this.reportId );
            System.debug( 'campaignId=' + this.campaignId );
            System.debug( 'campaignMemberStatus=' + this.campaignMemberStatus );
            System.debug( 'columnName=' + this.columnName );

            Reports.ReportExtendedMetadata metadata = Reports.ReportManager.describeReport( reportId ).getReportExtendedMetadata();
            Map<String, Reports.DetailColumn> reportColumnsMap = metadata.getDetailColumnInfo();

            System.debug( 'reportColumnsMap: ' + reportColumnsMap );

            if ( !reportColumnsMap.containsKey( columnName ) ) {
                throw new AddCampaignMembersByReportException( 'Report with id "' + reportId + '" is missing expected column "' + reportsettings[0].report_contact_or_lead_id_column_label__c + '" that references a record id like Contact.Id or Lead.Id' );
            }

        } catch ( Exception e ) {
			System.debug( 'exception ' + e );
            AddCampaignMembersByReportLogger.log( e );

        }

    }

    // ----------------------------------------------------

    public Iterable<ID> start( Database.BatchableContext context ) {

        try {

            System.debug( 'AddCampaignMembersByReportBatchable.start: ' + context );
            System.debug('this.reportId '+this.reportId);
			System.debug('this.columnName '+this.columnName);
            System.debug('this.columnDateTime '+columnDateTime);
            
            
            Iterable<ID> reportRowIdIterable = new NPSP_ReportService.ReportRowIdIterableIterator( this.reportId, this.columnName );

            Iterator<ID> reportRowIdIterator = reportRowIdIterable.iterator();

            // when running test ensure at most one batch execution will run, otherwise send back the real iterable
            return (Iterable<ID>) ( ( Test.isRunningTest() && reportRowIdIterator.hasNext() ) ? new List<ID>{ reportRowIdIterator.next() } : reportRowIdIterable );

        } catch ( Exception e ) {
			System.debug( 'start exception ' + e );
            AddCampaignMembersByReportLogger.log( context.getJobId(), e );

            return new EmptyIterator();

        }

    }

    public void execute( Database.BatchableContext context, List<ID> recordIds ) {

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( 'AddCampaignMembersByReportBatchable.execute: ' + context );
            
			system.debug('RecordTypeName: '+RecordTypeName);
            system.debug('columnDateTime: '+columnDateTime);
            
            if(RecordTypeName == 'Add_Campaign_Members'){
            	new AddCampaignMembersByReportService().addMembersToCampaign( recordIds, this.campaignId, this.campaignMemberStatus );
        	}
            if(RecordTypeName == 'Update_Field_on_Records'){
            	     
                	DateTime DateTimeNow =system.now();
                    List<sObject> recordstoupdate = new List<SObject>();
                    recordstoupdate.clear(); 
                
                    for(Id idToUpdate : recordIds ){
                        SObject o1 = idToUpdate.getSObjectType().newSObject(idToUpdate);                      
                        //change to columnName
                        o1.put(columnDateTime, DateTimeNow );
                        recordstoupdate.add(o1);
                    }
                
                update recordstoupdate;
        	}            
            
            

        } catch ( Exception e ) {

            Database.rollback( sp );

            AddCampaignMembersByReportLogger.log( context.getJobId(), e );

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( 'AddCampaignMembersByReportBatchable.finish: ' + context );

        AddCampaignMembersByReportLogger.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

    }

    // ----------------------------------------------------

    public class AddCampaignMembersByReportException extends Exception {}

    @TestVisible
    private class EmptyIterator implements Iterator<ID>, Iterable<ID> {

        public Boolean hasNext() {
            return false;
        }

        public ID next() {
            return null;
        }

        public Iterator<ID> iterator() {
            return new EmptyIterator();
        }

    }

}