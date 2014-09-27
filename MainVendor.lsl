//Main Dogecoin Vendor Script
// Functions as the central logic hub for vendor, bridges interface and checkout

list items;
list prices;

key config_card;
key item_card;
key rq;
integer line_num;

integer online = TRUE;
float sale_percentage;
string info_prefix = "Info-";
integer interface_link_chan = 980208;

integer txn_item_index;
key buyer;

integer parse_config(integer is_item_flag, string line)
{
    list params = llParseString2List(line,[":",","],[]);
    integer success = TRUE;
    
    if(is_item_flag)
    {
        if(llGetListLength(params) == 2)
        {    
            string item = llList2String(params,0);
            integer price = llList2Integer(params,1);
            
            if(item != "" && price >= 0)
            {
                items = items + item;
                prices = prices + price;
            } 
            else {success = FALSE;}      
        }
    }
    else
    {
        string param = llToUpper(llList2String(params,0));
        if(param == "ONLINE")
        { 
            if(llToUpper(llList2String(params,1)) == "FALSE"){online = FALSE;}
        }
        else if(param == "SALEPERCENT")
        {
            integer discount_pct = llList2Integer(params,1);
            if(discount_pct < 0){discount_pct = 0;}
            else if(discount_pct > 100){discount_pct = 100;}
            sale_percentage = (float)discount_pct/100.0;
        } 
        else if(param == "INFOPREFIX")
        {
            string prefix = llList2String(params,1);
            if(prefix != ""){info_prefix = prefix;}
        }
        else { success = FALSE; }
        //TODO: Add config option for interface link channel 
    }

    return success;
}

check_config(integer include_items_flag)
{ 
    integer need_reset = FALSE;
    if(include_items_flag)
    { if(config_card != llGetInventoryKey("Main_Config") || item_card != llGetInventoryKey("Item_Config")){ need_reset = TRUE; } }
    else { if(config_card != llGetInventoryKey("Main_Config")){ need_reset = TRUE; } }
    
    if(need_reset)
    {
        llOwnerSay("Configuration Changed. Resetting Vendor"); 
        llResetScript(); 
    }     
}

try_infocard_fetch(string item,key id)
{
    item = info_prefix + item;
    if(llGetInventoryType(item) != INVENTORY_NONE){ llGiveInventory(id,item); }
}

integer calc_sale_price(integer price)
{
    integer discount = (integer)(price * sale_percentage);
    return (price - discount); 
}

default
{
    on_rez(integer n){llResetScript();}
    
    state_entry()
    {
        config_card = llGetInventoryKey("Main_Config");
        rq = llGetNotecardLine("Main_Config",0);
    }
    
    dataserver(key id, string line)
    {
        if(rq == id)
        {
            if( line != EOF )
            {   
                if(!parse_config(FALSE,line)){ llOwnerSay("Couldn't load Main Config line " + (string)(line_num+1)); }
                line_num++;
                rq = llGetNotecardLine("Main_Config",line_num);
            }
            else
            {
                 if(online){ state load_items; } else { state offline; }   
            }    
        }
    }    
}

state load_items
{
    state_entry()
    {
        line_num = 0;
        item_card = llGetInventoryKey("Item_Config");
        rq = llGetNotecardLine("Item_Config",0);
    }
    
    dataserver(key id, string line)
    {
        if(rq == id)
        {
            if( line != EOF )
            {    
                if(!parse_config(TRUE,line)){ llOwnerSay("Couldn't load Item Config line " + (string)(line_num+1)); }
                line_num++;
                rq = llGetNotecardLine("Item_Config",line_num);
            }
            else
            {
                llOwnerSay("Finished loading " + (string)llGetListLength(items) + " items.");
                llOwnerSay("Vendor Online");
                state online;
            }    
        }
    } 
}

state online
{
    state_entry()
    {
        txn_item_index = -1;
        buyer = NULL_KEY;
    }

    link_message(integer orgin, integer chan, string msg, key agent)
    {
        if(chan == interface_link_chan)
        {
            //wait for messages triggering a transaction or a info request
            list params = llParseString2List(msg,[":"],[]);
            if(llGetListLength(params) == 2)
            {
                string command = llList2String(params,0);
                string item = llList2String(params,1);
                integer index = llListFindList(items,[item]);
                
                if(command == "INFO")
                {  
                    if(index != -1)
                    {
                        string item_message =  item + " - " + (string)calc_sale_price(llList2Integer(prices,index)) + "Ð";
                        llSay(0,item_message);
                    }
                    try_infocard_fetch(item,agent);
                }
                else if (command == "PURCHASE")
                {
                    if(index != -1 && llGetInventoryType(llList2String(items,index)) != INVENTORY_NONE)
                    {
                        txn_item_index =  index;
                        buyer = agent;
                        state txn_in_progress;
                    }
                    else { llSay(0,"Sorry, this item is not for sale.");}
                }    
            }
        }   
    }

    changed(integer change)
    { if(change & CHANGED_INVENTORY){check_config(TRUE);} }           
}

state offline
{
    state_entry(){ llOwnerSay("Vendor Offline."); }
    
    touch_start(integer n)
    {
        if(llDetectedKey(0) != llGetOwner())
        {
            llSay(0,"Sorry, this vendor is currently offline.");    
        }    
    }

    changed(integer change)
    { if(change & CHANGED_INVENTORY){check_config(FALSE);} }            
}

state txn_in_progress
{
    state_entry()
    {
        integer price = calc_sale_price(llList2Integer(prices,txn_item_index)); 
        llMessageLinked(LINK_SET,price,"CHECKOUT",buyer);
    }
    
    link_message(integer origin, integer status, string msg, key id)
    {
        if (msg == "COMPLETE")
        {
            if (status == TRUE)
            {
                llSay(0,"Vending item, please wait!");
                string item = llList2String(items,txn_item_index);
                llGiveInventory(buyer,item);
                state online;
            }
            else 
            { 
                llSay(0,"Purchase Canceled.");
                state online;
            }
        }
    }    
}
