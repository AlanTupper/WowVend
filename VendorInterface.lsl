integer link_chan = 980208;

integer SCREEN = 1;
integer BUY_BTTN = 2;
integer BACK_BTTN = 3;
integer FWD_BTTN = 4;

integer SCREEN_FACE = 0;

string image_prefix = "@@";

list slides;
integer num_of_slides;

integer index;

update_screen()
{
    string slide = llList2String(slides,index);
    llSetLinkTexture(SCREEN,slide,SCREEN_FACE); 
}

move(string dir)
{
    integer old_index = index;
    
    if(dir == "FORWARD" && (index+1) <= (num_of_slides-1)){ index++; }
    else if(dir == "BACK" && index-1 >= 0){ index--; }
    
    if( old_index != index)
    {
        update_screen(); 
        announce_item();
    }    
}

announce_item()
{
    string message = "[ " + (string)(index+1) + " / " + (string)num_of_slides + " ] " + get_item();
    llWhisper(0, message);
}

string get_item()
{
    string slide = llList2String(slides,index);
    string item = llDeleteSubString(slide,0,llStringLength(image_prefix)-1);
    return item;    
}

send_command(string command,key toucher)
{
    command = llToUpper(command) + ":" + get_item();
    llMessageLinked(LINK_SET,link_chan,command,toucher);
}

default
{
    state_entry()
    {
        
        
        
        integer possible_slides = llGetInventoryNumber(INVENTORY_TEXTURE);
        integer i;
        string texture;
        
        for(;i < possible_slides;i++)
        {
            texture = llGetInventoryName(INVENTORY_TEXTURE,i);
            if(llSubStringIndex(texture,image_prefix) == 0){ slides = slides + texture; }
        }
        
        num_of_slides = llGetListLength(slides);
        update_screen();        
    }

    
    touch_start(integer n)
    {
        integer link_touched = llDetectedLinkNumber(0);
        key toucher = llDetectedKey(0);
        
        if(link_touched < 5)
        {
            if(link_touched == SCREEN){send_command("INFO",toucher);}
            else if(link_touched == BUY_BTTN){send_command("PURCHASE",toucher);}
            else if(link_touched == BACK_BTTN){move("BACK");}
            else if(link_touched == FWD_BTTN){move("FORWARD");}       
        }
    }
    
}
