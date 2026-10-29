trigger OpportunityActivityTaskTrigger on Task (
    after insert,
    after update,
    after delete
){

    if(Trigger.isAfter){

        if(Trigger.isInsert){

            OpportunityActivityHandler.processTasks(
                Trigger.new
            );

        }

        if(Trigger.isUpdate){

            OpportunityActivityHandler.processTasks(
                Trigger.new
            );

        }

        if(Trigger.isDelete){

            OpportunityActivityHandler.processTasks(
                Trigger.old
            );

        }

    }

}