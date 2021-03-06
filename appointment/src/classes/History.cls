/*
* This class is used to model a full history timeline for an sObject
* pulling data from most available sources, and showing a unified view.
* Think of this as an enhanced version of the history related list.
* @author cpeterson
*/
public with sharing class History {

    public sObject subject {get;set;}
    public List<HistoryEvent> events {get;set;}
    public transient Schema.DescribesObjectResult objectType {get;set;}
    public List<FieldHistory> injectedResults = new List<FieldHistory>(); // DO NOT POPULATE OUTSIDE OF TESTS!
    private Map<string,Schema.sObjectField> fields;
    
    public History(sObject subject) {
    
        this.subject = subject;
        this.events = new List<HistoryEvent>();
        
        objectType = subject.getsObjectType().getDescribe();
        fields = objectType.fields.getMap();
        
    }
    
    public void buildEntries() {
    
        events = new List<HistoryEvent>();
        Schema.Describesobjectresult r = subject.getSObjectType().getDescribe();
        List<Schema.ChildRelationship> c = r.getChildRelationships();
        List<string> result = new List<string>();
        HistoryEvent event;
        
        for(Schema.Childrelationship child:c) {
        
            string childName = child.getChildsObject().getDescribe().getName();
            
            if(child.getChildSObject().getDescribe().isQueryable()) {
            
                String query;
                
                // Some sObjects are special and delicate like snowflakes.
                if(childName == 'Note') {
                    query = 'SELECT id, title, CreatedBy.name, CreatedDate FROM '+child.getChildsObject().getDescribe().getName()+' WHERE '+child.getField()+' = \''+subject.id+'\'';
                    addNotes( Database.Query(query) );
                    
                } else if(childName == 'Event' || childName == 'Task') { // :( at the standardness of standard objects
                    query = 'SELECT id, subject, CreatedById, CreatedDate FROM '+child.getChildsObject().getDescribe().getName()+' WHERE '+child.getField()+' = \''+subject.id+'\'';
                    addActivities( Database.Query(query) );
                    
                } else if(childName.contains('__History')) {
                    if(injectedResults.size() > 0) {
                        // this is from inside a test
                        addHistory( injectedResults );
                    } else {
                        query = 'SELECT id, field, oldValue, newValue, CreatedById, CreatedDate FROM '+child.getChildsObject().getDescribe().getName()+' WHERE '+child.getField()+' = \''+subject.id+'\'';
                        addHistory( uglyHack( Database.Query(query) ) );
                    }
                }else if(childName.contains('PartnerNetwork') 
                    || childName == 'ProcessInstance'
                    || childName.contains('__Tag')
                    || childName == 'EntitySubscription') { // Some sObjects are there just to make life hard...
                    continue;
                    
                }else {
                    try{
                        query = 'SELECT id, name, CreatedById, CreatedDate FROM '+child.getChildsObject().getDescribe().getName()+' WHERE '+child.getField()+' = \''+subject.id+'\'';
                        addGeneric( Database.Query(query) );
                    } catch (System.QueryException e) {
                        System.debug('Unsupported object found! '+childName);
                    }
                    
                }
                
            } else {
                System.debug(child.getChildsObject().getDescribe().getLabel()+' is not queryable.');
            }
            
        }
        
        quicksort(events, 0, events.size() -1 );
        
    }
    
    private void addNotes(List<Note> notes) {
    
        HistoryEvent event;
        
        for(Note thisNote:notes) {
            event = new HistoryEvent(thisNote.CreatedBy, thisNote.CreatedDate,thisNote.title,'New Note');
            event.detailId = thisNote.id;
            events.add(event);
        }
        
    }
    
    // Adds a list of either tasks or events
    private void addActivities(List<sObject> activities) {
    
        HistoryEvent event;
        string activityType;
        Map<id,User> users = new Map<id,User>([SELECT id, name FROM User WHERE id IN :Utils.getIdFields(activities,'CreatedById')]);
        
        for(sObject thisActivity:activities) {
        
            if( activityType == null ) { activityType = thisActivity.getSObjectType().getDescribe().getLabel(); } 
            event = new HistoryEvent(
                (User) users.get( (id) thisActivity.get('CreatedById') ),
                DateTime.valueOf( thisActivity.get('CreatedDate') ),
                String.valueOf( thisActivity.get('subject') ),
                'New '+activityType);
            event.detailId = thisActivity.id;
            events.add(event);

        }
        
    }
    
    private void addHistory(List<FieldHistory> fieldChanges) {
    
        HistoryEvent event;
        String tableName = objectType.getName();
        tableName = tableName.replace('__c','');
        tableName = tableName+'__History';
        Set<id> userIds = new Set<id>();
        
        for(FieldHistory fieldChange:fieldChanges) {
            userIds.add(fieldChange.CreatedById);
        }
        
        Map<id,User> users = new Map<id,User>([SELECT id, name FROM User WHERE id IN :userIds]);
        
        for(FieldHistory fieldChange:fieldChanges) {
        
            String oldValue = fieldChange.oldValue;
            boolean isJunk = true;
            
            try{
                id thisId = oldValue;
            }catch(System.StringException e) {
                //A junk row with IDs rather than names is inserted for every change, we want to ignore that one.
                isJunk = false;
            }
            
            if(!isJunk) {
            
                String description = parseFieldHistory(fieldChange);
                System.debug('Found description: '+description);
                event = new HistoryEvent(
                    users.get( fieldChange.CreatedById ),
                    fieldChange.CreatedDate, 
                    description, 'Record edited');
                System.debug('This event is: '+event);
                events.add(event);
                
            }
            
        }
        
    }
    
    private void addGeneric(List<sObject> objects) {
    
        HistoryEvent event;
        string objectType;
        Map<id,User> users = new Map<id,User>([SELECT id, name FROM User WHERE id IN :Utils.getIdFields(objects,'CreatedById')]);
        
        for(sObject thisObject:objects) {
        
            if( objectType == null ) { objectType = thisObject.getSObjectType().getDescribe().getLabel(); } 
            event = new HistoryEvent(
                (User) users.get( (id) thisObject.get('CreatedById') ), 
                DateTime.valueOf( thisObject.get('CreatedDate') ), 
                String.valueOf( thisObject.get('name') ), 
                'New '+objectType);
            event.detailId = thisObject.id;
            events.add(event);
            
        }
        
    }
    
    private string parseFieldHistory(FieldHistory fieldHistory) {
    
        string result = 'this is a bad value';
        string oldValue = fieldHistory.oldValue;
        string newValue = fieldHistory.newValue;
        System.debug('FieldHistory field value is: '+fieldHistory.Field);
        
        if(String.ValueOf( fieldHistory.Field ) == 'created') {
            return 'Created';
        } // special case for the special created field
        
        // Get the label for the related field. We don't want to show the developerName in the UI
        Schema.sObjectField F = fields.get( fieldHistory.Field );
        string fieldLabel;
        try{
            if(fieldHistory.field == 'RecordType') {
                fieldLabel = 'Record Type'; //Record type is 'special' and doesn't have a label.
            } else {
                fieldLabel = F.getDescribe().getLabel();
            }
        } catch (System.Nullpointerexception e) {
            if(fieldHistory.field == 'Owner') {
                fieldLabel = 'Owner';
            }
            //fieldLabel = F.getDescribe().getName();
        }
        
        System.debug('Field label is: '+fieldLabel);
        
        if(oldValue == null && newValue == null) {
            result = fieldLabel+' modified';
        } else {
            result = 'Field '+fieldLabel+' changed from '+oldValue+' to '+newValue;
        }
        
        return result;
        
    }
    
    /*
    * From http://blog.sforce.com/sforce/2008/09/sorting-collect.html
    * Modified to our needs by cpeterson
    */
    private static void quicksort(List<HistoryEvent> a, Integer lo0, Integer hi0) {
    
        Integer lo = lo0;
        Integer hi = hi0;
        
        if (lo >= hi) {
            return;
        } else if( lo == hi - 1 ) {
        
            if (a[lo].timestamp > a[hi].timestamp) {
                HistoryEvent o = a[lo];
                a[lo]         = a[hi];
                a[hi]         = o;
            }
            
            return;
            
        }
        
        HistoryEvent pivot = a[(lo + hi) / 2];
        a[(lo + hi) / 2] = a[hi];
        a[hi] = pivot;
        
        while( lo < hi ) {
        
            while (a[lo].timestamp <= pivot.timestamp && lo < hi) { lo++; }
            while (pivot.timestamp <= a[hi].timestamp && lo < hi ) { hi--; }
            
            if( lo < hi ) {
                HistoryEvent o = a[lo];
                a[lo]         = a[hi];
                a[hi]         = o;
            }
            
        }
        
        a[hi0] = a[hi];
        a[hi] = pivot;
        
        quicksort(a, lo0, lo-1);
        quicksort(a, hi+1, hi0);
        
    }
    
    public void invertList() {
    
        Integer lo = 0;
        Integer hi = events.size() - 1;
        
        while(lo < hi) {
        
            HistoryEvent o = events[lo];
            events[lo] = events[hi];
            events[hi] = o;
            lo++;
            hi--;
            
        }
        
    }
    
    public class HistoryEvent{
    
        public String description {get; set;}
        public String eventType {get; set;}
        public DateTime timestamp {get; set;}
        public User modifiedBy {get; set;}
        public id detailId {get; set;}
        
        public HistoryEvent(User modifiedBy, DateTime timestamp, String description, String eventType) {
        
            this.modifiedBy = modifiedBy;
            this.timestamp = timestamp;
            this.description = description;
            this.eventType = eventType;
            
        }
        
        public string getShortDate() {
            return timestamp.format('MM/dd hh:mm'); //short format used for accordion pannel
        }
        
        public string getFormatted() {
            return timestamp.format(); //timestamp localized to current user
        }
        
    }
    
    public class FieldHistory{
    
        // So this class is stupid, almost useless, but mandatory to test field history
        
        public id parentId;
        public string oldValue;
        public string newValue;
        public string field;
        public id createdByid;
        public DateTime createdDate;
        
        public FieldHistory(sObject subject) {
        
            createdById = (id) subject.get('CreatedById');
            //parentId = (id) subject.get('parentId');
            oldValue = String.valueOf( subject.get('oldValue') );
            newValue = String.valueOf( subject.get('newValue') );
            createdDate = (DateTime) subject.get('CreatedDate');
            field = String.valueOf( subject.get('field') );
            
        }
        
        public FieldHistory(id createdById, string oldValue, string newValue, DateTime createdDate, string field) {
        
            this.createdById = createdById;
            this.oldValue = oldValue;
            this.newValue = newValue;
            this.createdDate = createdDate;
            this.field = field;
            
        }
        
    }
    
    public static List<FieldHistory> uglyHack(List<sObject> subjects) {
    
        List<FieldHistory> result = new List<FieldHistory>();
        
        for(sObject subject:subjects) {
            result.add( new FieldHistory(subject) );
        }
        
        return result;
        
    }
    
}