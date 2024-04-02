/*
*******************************************************************************************************
* (C) Copyright 2020 Yokogawa. All rights reserved.
* This code is property of Yokogawa. Use, duplication and
* disclosure in any form without permission of copyright holder is prohibited.
* 
******************************************************************************************************* 
* @author Chitrakishore
* @version 1.0
* @created 15/06/2020
* @description 
* This class is used to write the methods for common functionality for all the modules.
*
* @test class name - YG_CommonControllerTest
*
*  Change History:
*  MM/DD/YYYY			Developer Name			Comments
*  12/04/2020			Jayaprasath				Added getMenuInfo()
*  04/19/2021			Kavya					Removed Customer_Plant__c Object and replaced with AccountContactRelation Object
*
*/

public class YG_CommonController {
    
    public static User userInformation =  YG_Utility.getLoggedInUserInfo(UserInfo.getUserId());
    
    @AuraEnabled
    public static CommonWrapper getPlantInfo(String langCode){
        
        Id cusPltId;
        
        List<DataWrapper> wrapperList = new List<DataWrapper>();
        list<string> plantCodeList = new list<string>();
        CommonWrapper commonWrapper = new CommonWrapper();
        CheckSystemStations checkSystemStationPlants = new CheckSystemStations();
        list<string> stationPlantList = new list<string>();
        list<string> systemPlantList = new list<string>();
        try{
            if(null == langCode){
                langCode = YG_Constants.languageValue;
            }
            
            // Retrieve logged in user's plants info
            List<AccountContactRelation> cusPlantList = YG_HelperClass.getCusPlantInfo(userInformation.ContactId,langCode);
            for(AccountContactRelation cusPlant: cusPlantList){
                plantCodeList.add(cusPlant.Account.AccountNumber);
            }
            if(!plantCodeList.isempty()){
                checkSystemStationPlants = checkSystemStationPlants(plantCodeList);
                systemPlantList = checkSystemStationPlants.systemPlantCodes;
                stationPlantList = checkSystemStationPlants.stationPlantCodes;
            }
            
            for(AccountContactRelation cusPlant: cusPlantList){
                DataWrapper wrapper = new DataWrapper();
                wrapper.plantCode = cusPlant.Account.AccountNumber;
                wrapper.plantName = cusPlant.Account.Name;
                wrapper.isSoftwareAvail = systemPlantList.contains(cusPlant.Account.AccountNumber) ? true : false;
                wrapper.isStationAvail = stationPlantList.contains(cusPlant.Account.AccountNumber) ? true : false;
                // wrapper.isStationAvail = true;
                wrapperList.add(wrapper);
                
            }
            commonWrapper.wrapper = wrapperList;    
            
        }catch(Exception e){
            YG_Utility.logError('Plant Page','Community Component Error',e.getStackTraceString(),
                                'Class:YG_CommonController; Method: getPlantInfo(); Line #:'+e.getLineNumber()+'; Message:'+e.getMessage(),
                                UserInfo.getUserId());
        }
        system.debug('commonWrapper:: '+commonWrapper);
        return commonWrapper;
    }
    
    public class CommonWrapper{
        @AuraEnabled public List<DataWrapper> wrapper; 
    }
    
    public class DataWrapper{
        @AuraEnabled public string plantCode; 
        @AuraEnabled public string plantName;
        @AuraEnabled public boolean isSoftwareAvail;
        @AuraEnabled public boolean isStationAvail;
    }
    
    //This method is used to check the user's account has assigned plant or not
    @AuraEnabled 
    public static String checkContractOrIndividualCustomer(){
        Id accId = userInformation.Contact.AccountId;
        Id conId = userInformation.Contact.Id;
        String result;
        //Query to get the account number
        Account acc=[Select Id, AccountNumber From Account Where Id=: accId];
        if(acc.AccountNumber == null){
            result = YG_Constants.request_Product;
        }else{
            result = YG_Constants.request_Plant;
        }
        return result;
    }
    
    //This method is used to check the user's has product
    @AuraEnabled 
    public static MenuWrapper getMenuInfo(){
        Id conId = userInformation.Contact.Id;
        Id accId = userInformation.Contact.AccountId;
        Map<String, YG_Community_Configuration__c> allValues = new Map<String, YG_Community_Configuration__c>();        
        allValues = YG_Community_Configuration__c.getAll();
        Id selfRegAccId = allValues.get(YG_Constants.SelfRegisterAccId).Text_1__c;
        boolean checkSelfUser = userInformation.contact.Self_Register_User__c;
        String result;
        MenuWrapper menu = new MenuWrapper();
        try{
            if(accId != null && conId != null){
                List<Customer_Asset__c> custAsst = null;
                if(accId.equals(selfRegAccId) || (accId != selfRegAccId && checkSelfUser == true)){
                    custAsst = [Select Id from Customer_Asset__c where Contact__c =: conId ];
                }else{
                    custAsst = [Select Id from Customer_Asset__c where (Account__c =: accId OR Contact__c =: conId) Limit 49999];
                }
                
                List<AccountContactRelation> custPlnt = [Select Id,Account.Has_Asset__c,Account.AccountNumber,IsDirect,
                                                         status__c from AccountContactRelation where ContactId = : conId ];
                
                set<string> myset = new set<string>(); 
                
                //get onboarding days
                Integer days = Integer.valueOf(allValues.get(YG_Constants.OnBoardingDays).Text_1__c);
                
                Contact con = [Select Id, First_Login_Date__c, On_Boarding_Status__c, Portal_User_Roles__c, 
                               Account.AccountNumber,HideAccountSetup__c From Contact Where Id = :conId Limit 1];
                 
                if(con != null){
                    if(con.First_Login_Date__c != null){
                        menu.hideStatus=con.HideAccountSetup__c; //3352
                        Date endDate = con.First_Login_Date__c.addDays(days);
                        menu.onboardingStatus = getOnboardingMenu(endDate, con.On_Boarding_Status__c, con.Portal_User_Roles__c, con.Account.AccountNumber );
                        
                    }
                }
                
                //to identify Self Reg User
                if(accId == selfRegAccId || (accId != selfRegAccId && checkSelfUser == true)){
                    System.debug('Inside 1');
                    if(custAsst.size() != 0){
                        menu.notify = 0; 
                    }
                    else{
                        menu.notify = 1;
                    }
                    menu.systemCount =  0; 
                    menu.selfRegUser = true; 
                    menu.productCount =  custAsst.size(); 
                    System.debug('menu.selfRegUser::'+menu.selfRegUser);                        
                }
                else{
                    for(AccountContactRelation cp :custPlnt){ 
                        if(cp.Status__c == YG_Constants.Approved_site_access && cp.IsDirect && cp.Account.Has_Asset__c){
                            myset.add(cp.Account.AccountNumber); 
                        }
                        if(cp.Status__c == YG_Constants.Approved_site_access && !cp.IsDirect){
                            myset.add(cp.Account.AccountNumber);
                        }
                    }
                    
                    if(myset.size()>0){
                        menu.systemCount =  myset.size(); 
                    }else{
                        menu.systemCount =  0; 
                    }
                    
                    menu.productCount =  custAsst.size(); 
                    menu.selfRegUser = false;                
                    if(custPlnt.size() == 0 && custAsst.size() == 0){
                        menu.notify = 2; 
                    }
                }
            }
            
        }
        
        catch(Exception e){
            YG_Utility.logError('Menu page','Community Component Error',e.getStackTraceString(),'Class:YG_CommonController; Method: getMenuInfo(); Line #:'+e.getLineNumber()+'; Message:'+e.getMessage(),UserInfo.getUserId());
        }
        System.debug('menu:: '+menu);
        return menu;
    }
    
    public static boolean getOnboardingMenu(Date endDate, String onBoardingString, String role, string accountNo ){
        boolean onboardingStatus = false;
        if(System.today() > endDate){
            onboardingStatus = true;
        }else if(onBoardingString != null && onBoardingString.indexOf(';') != -1){
            List<String> statusList = new List<String>();
            statusList = onBoardingString.split(';');
            if(statusList.size() == 4 && (role == 'CA' || role == 'SA')){
                onboardingStatus = true;
            }else if(statusList.size() == 3 && role == 'CU' && accountNo != null){
                onboardingStatus = true;
            }else if(statusList.size() == 2 && role == 'CU' && accountNo == null){
                onboardingStatus = true;
            }
        }
        return onboardingStatus;
    }
    
    public class MenuWrapper{
        @AuraEnabled public Integer productCount = 0;
        @AuraEnabled public Integer systemCount = 0;
        @AuraEnabled public Integer notify = 1;
        @AuraEnabled public Boolean selfRegUser;
        @AuraEnabled public Boolean onboardingStatus = false;
        @AuraEnabled public Boolean hideStatus = false; // 3352
    }
    
    @auraEnabled
    public static serialWrap checkSerialNoRegistered(string serialNo){
        system.debug('serialNo:: '+serialNo);
        Id accId = userInformation.Contact.AccountId;
        Id conId = userInformation.Contact.Id;
        boolean checkSelfUser = userInformation.contact.Self_Register_User__c;
        Map<String, YG_Community_Configuration__c> allValues = YG_Community_Configuration__c.getAll();
        String selfRegAccId = allValues.get(YG_Constants.SelfRegisterAccId).Text_1__c; 
        List<Customer_Asset__c> assetList=new List<Customer_Asset__c>();
        serialWrap wrap = new serialWrap();
        if(serialNo != null){
            if(accId==selfRegAccId || (accId!=selfRegAccId && checkSelfUser == true)){
                assetList = [SELECT ID FROM Customer_Asset__c where Contact__r.ID =: conId and Asset__r.serialnumber =:serialNo];
            }else{
                assetList = [SELECT ID FROM Customer_Asset__c where (Account__r.ID =: accId OR Contact__r.ID =: conId) and Asset__r.serialnumber =:serialNo];
            }
            
            if(assetList.size()>0){
                wrap.registered = true;
            }else{
                wrap.registered = false;
            }
        }
        system.debug('wrap:: '+wrap);
        return wrap;
    }
    
    public class serialWrap{
        @AuraEnabled public Boolean registered;
    }
    
    //This method is used to check the station for plants
    public static CheckSystemStations checkSystemStationPlants(list<string> plantCode){
        
        CheckSystemStations wrap = new CheckSystemStations();
        Id accId = userInformation.Contact.AccountId;
        list<string> stationPlantList = new list<string>();
        list<string> systemPlantIdList = new list<string>();
        list<string> systemPlantList = new list<string>();
        list<id> plantIdList = new list<id>();
        list<Account> plantList = new list<Account>();
        List<AggregateResult> projList = new List<AggregateResult>(); //List to store the project record
        //Map to get the Product type using custom metadata types
        Map<String, String> productTypeMap = YG_HelperClass.getMaterialGrpProdType();
        List<String> softwareMaterialGrpList =new List<String>();
        for(String str : productTypeMap.keySet()){
            if(YG_Constants.Software.equalsIgnorecase(productTypeMap.get(str))){
                softwareMaterialGrpList.add(str);
            }
        }
        if(!plantCode.isEmpty()){
            plantList = [SELECT Id FROM Account WHERE (AccountNumber =: plantCode AND ParentId = :accId And Type = 'Plant')
                 			OR (AccountNumber =: plantCode AND Has_Asset__c = True)];
            for(account acc: plantList){
                plantIdList.add(acc.Id);
            }
        }
        system.debug('plantIdList:: '+plantIdList);
        Set<String> plantSet = new Set<String>(); // system 
        // for(Project__c  prj :[select PlantAccount__r.Id, PlantAccount__r.AccountNumber,
        //         (SELECT Id FROM Assets__r WHERE PlantAccount__r.Id IN :plantIdList AND Station_Type__c != null LIMIT 1) from Project__c  where PlantAccount__r.Id IN: plantIdList
        //         AND System_Status__c NOT IN ('Decommissioning', 'Illegal', 'Unidentified', 'System Updated')
        //         AND PlantAccount__r.AccountNumber != null]){
                
                    // if (!prj.Assets__r.isEmpty()) {
                    //     plantSet.add(prj.PlantAccount__r.AccountNumber);
                    // }
            for(Project__c  prj : [select PlantAccount__r.Id, PlantAccount__r.AccountNumber from Project__c where PlantAccount__r.Id IN: plantIdList
            AND System_Status__c NOT IN ('Decommissioning', 'Illegal', 'Unidentified', 'System Updated')
            AND PlantAccount__r.AccountNumber != null]){
            
        }

        if(!plantIdList.isEmpty()){
            //checking for stations
            for(AggregateResult res: [Select PlantAccount__c plt, PlantAccount__r.AccountNumber pltNum From Asset where PlantAccount__r.Id IN: plantIdList
                                      AND Station_Type__c != null group by PlantAccount__c, PlantAccount__r.AccountNumber]){

                if(plantSet.Contains((string)res.get('pltNum'))){
                    stationPlantList.add((string)res.get('pltNum'));
                } 
            }
            system.debug('stationPlantList:: '+stationPlantList);
            //checking for software license
        	for(AggregateResult res: [Select PlantAccount__r.Id pltId, PlantAccount__r.AccountNumber from Project__c 
                                      where PlantAccount__r.Id=:plantIdList group by PlantAccount__r.Id, PlantAccount__r.AccountNumber]){
                systemPlantIdList.add((string)res.get('pltId'));
            }
            system.debug('systemPlantIdList:: '+systemPlantIdList);
            //checking the software asset products
            if(!systemPlantIdList.isEmpty()){
                for(AggregateResult ast: [Select Product2Id, PlantAccount__r.AccountNumber pltNum From Asset Where PlantAccount__c = :systemPlantIdList 
                                          AND Product2.Material_Group__c IN: softwareMaterialGrpList Group By Product2Id, PlantAccount__r.AccountNumber]){
                	// systemPlantList.add((string)ast.get('pltNum'));  
                    if(plantSet.Contains((string)ast.get('pltNum'))){
                        systemPlantList.add((string)ast.get('pltNum'));
                    }                     
                }
                system.debug('systemPlantList:: '+systemPlantList);
            }
        }
        wrap.systemPlantCodes = systemPlantList;
        wrap.stationPlantCodes = stationPlantList;
        
        return wrap;
    }
    
    public class CheckSystemStations{
        public list<string> systemPlantCodes;
        public list<string> stationPlantCodes;
    }
}