/**
 * Modified from Andrew Fawcett's Github. An amazing tool worth checking out: https://github.com/afawcett/declarative-lookup-rollup-summaries
 * His Copyright statement still applies: 2013, Andrew Fawcett
 * All rights reserved.
 * Added for tool by Doug Ayers (douglascayers.com)
 * https://github.com/DouglasCAyers/sfdc-add-campaign-members-by-report
 *
 * Developed by danhowellnz from http://www.gravitylab.nz/
**/


public with sharing class SetSchedulerController 
{
    private ApexPages.StandardController standardController;
    public iD recordID { get; set; }
    public String minute { get; set; }
    public List<SelectOption> minutes { get; set; }
    public List<String> hour { get; set; }
    public List<String> day { get; set; }
    public List<String> month { get; set; }
    public List<String> weekday { get; set; }
    public String uniqueNameForJob { get; set; }
    
    public SetSchedulerController (ApexPages.StandardController standardController)
    {   
        //Varaibles
        uniqueNameForJob = 'AddCampaignMembersJob-'+recordID;
        //And change the apex class on line 73
        
        // Ensure the unique name field is included in the standard controller read fields
        this.standardController = standardController;

        
        // Minutes for fields
        minutes = new List<SelectOption>();
        for(Integer minute=0; minute<60; minute++) {
            minutes.add(new SelectOption(minute+'', minute+''));
        }

        // Default is 2am everyday
        minute = '0';
        hour = new List<String> { '2' };
        day = new List<String> { '*' } ;
        month = new List<String> { '*' };
        weekday = new List<String> { '?' };
    }
    
    public PageReference scheduleJob()
    {
        try
        {
            // Build the CRON string
            String cronString = 
                String.join(
                    new List<String> {
                        '0',
                        minute,
                        String.join(hour, ','),
                        String.join(day, ','),
                        String.join(month, ','),
                        String.join(weekday, ',') }, 
                    ' ');
            
            //Remove existing schedules
            for (CronTrigger t : [select Id,CronJobDetail.name,CronExpression from CronTrigger where CronJobDetail.name=:uniqueNameForJob]) {
                try {
                    System.abortJob(t.Id);
                }catch (Exception e){}
            }
            
            // Kickoff the calculate job for this lookup
            System.schedule(uniqueNameForJob, cronString, new AddCampaignMembersByReportSchedulable()   );
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Job scheduled!'+uniqueNameForJob));
        }
        catch (Exception e)
        {
            ApexPages.addMessages(e);
            return null;
        }



        return standardController.view();
    }
}