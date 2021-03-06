public with sharing class VersatileClass {

private Account account;

public VersatileClass(){
    system.debug('OPERATING AS CONTROLLER');
        if(System.currentPageReference().getParameters().get('id')==null){
            //Include error checking here
        } else{
            string AId = System.currentPageReference().getParameters().get('id');
            account = [select id, name from Account where id = :AId];
            //And whatever else you want to do
        }
}

public VersatileClass(ApexPages.StandardController controller) {
    system.debug('OPERATING AS EXTENSION');
        if(System.currentPageReference().getParameters().get('id')==null){
            //Include error checking here
        } else{
            this.account = (Account)controller.getRecord();
            //And whatever else you want to do
        }
    }
}