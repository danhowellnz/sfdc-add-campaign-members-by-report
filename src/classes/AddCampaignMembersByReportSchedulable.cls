/**
 * Developed by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/sfdc-add-campaign-members-by-report
 */
global with sharing class AddCampaignMembersByReportSchedulable implements Schedulable {

    private Integer batchSize { get; set; }

    global AddCampaignMembersByReportSchedulable() {
        this( 200 );
    }

    global AddCampaignMembersByReportSchedulable( Integer batchSize ) {
        this.batchSize = batchSize;
        system.debug('this.batchSize '+this.batchSize);
    }

    global void execute( SchedulableContext context ) {

        System.debug( 'AddCampaignMembersByReportSchedulable.execute: ' + context );

        for ( Scheduled_Report_Operations__c setting : [select Id, Report_ID__c,Batch_Size__c,RecordType.developername,
                                                        Month__c, Hour__c,Days_of_the_Week__c, Days_in_month__c                                                
                                                        from Scheduled_Report_Operations__c where (Active__c = true AND Report_ID__c != null)]  ) {

            System.debug( setting );
            
            //let's apply the tests
            //checked for active and has report id in query
            boolean pass = true;
            DateTime d = datetime.now();
			String monthName= d.format('MMMMM');  
            String Hour= d.format('HH');  
            String daytext = d.format('EEEE');
            string daynumber = d.format('d');
			system.debug(monthName +'  / '+Hour +'  / '+daytext +'  / '+daynumber);                                                            
                                                            
            //check month
            if(!setting.month__c.contains( 'EVERY MONTH' ) && !setting.Month__c.contains(monthName) )
                pass = false;
                                                            
            //check hour
            if(!setting.Hour__c.contains( 'EVERY HOUR' ) && !setting.Hour__c.contains(hour) )
                pass = false;            
 
            //check Days_in_month__c
            if(setting.Days_in_month__c != null && !setting.Days_in_month__c.contains( 'EVERY DAY' ) && !setting.Days_in_month__c.contains(daynumber) )
                pass = false;                                                            
            //check Days_of_the_Week__c
            if(setting.Days_of_the_Week__c != null && !setting.Days_of_the_Week__c.contains( 'EVERY DAY' ) && !setting.Days_of_the_Week__c.contains(daytext) )
                pass = false;                                                              
                                                            
                                                            
            if(pass = true){
                system.debug('starting batch');
				this.batchSize = setting.Batch_Size__c == null ? this.batchSize : integer.valueOf(setting.Batch_Size__c);
            	Database.executeBatch( new AddCampaignMembersByReportBatchable( setting.Id, setting.RecordType.developername ), this.batchSize );
            }

        }


    }

}