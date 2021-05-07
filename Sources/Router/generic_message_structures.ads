--
--  Framework: Uwe R. Zimmer, Australia, 2015
--

with Ada.Strings.Bounded;           use Ada.Strings.Bounded;
with Generic_Routers_Configuration;

generic
   with package Routers_Configuration is new Generic_Routers_Configuration (<>);

package Generic_Message_Structures is

   use Routers_Configuration;

   package Message_Strings is new Generic_Bounded_Length (Max => 80);
   use Message_Strings;

   subtype The_Core_Message is Bounded_String;

   type Messages_Client is record
      Destination : Router_Range;
      The_Message : The_Core_Message;
   end record;

   type Messages_Mailbox is record
      Sender      : Router_Range     := Router_Range'Invalid_Value;
      The_Message : The_Core_Message := Message_Strings.To_Bounded_String ("");
      Hop_Counter : Natural          := 0;
   end record;

   -- Leave anything above this line as it will be used by the testing framework
   -- to communicate with your router.

   --  Add one or multiple more messages formats here ..

   ---------------------------------------------------------------------------
   -- Routing Table Setup
   -- Based on setup from https://www.youtube.com/watch?v=GtgIV8kwqpA&ab_channel=KnowledgeThrusters
   type Routing_Table_Entry is record
      Router_ID : Router_Range := Router_Range'Invalid_Value; -- Router ID
      Distance : Natural := Natural'Invalid_Value; -- How many hops
      Next_Hop : Router_Range; -- Which router connected to me is connected to it
   end record;

   type Routing_Table_Type is array (Router_Range) of Routing_Table_Entry;
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Messages

   -- Used to send messages between routers
   type Router_Message is record
      Sender : Router_Range := Router_Range'Invalid_Value;
      Destination : Router_Range := Router_Range'Invalid_Value;
      The_Message : The_Core_Message;
      Hop_Counter : Natural := 0;
   end record;

   -- Used to send routing tables between routers
   type Routing_Table_Message is record
      Routing_Table : Routing_Table_Type;
      Sender : Router_Range := Router_Range'Invalid_Value;
   end record;
   ---------------------------------------------------------------------------

end Generic_Message_Structures;
