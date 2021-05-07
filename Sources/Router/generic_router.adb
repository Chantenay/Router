--
--  Framework: Uwe R. Zimmer, Australia, 2019
--

with Exceptions; use Exceptions;
with Queue_Pack_Protected_Generic;
-- with Ada.Text_IO; use Ada.Text_IO;

package body Generic_Router is

   task body Router_Task is

      Connected_Routers : Ids_To_Links;

   begin
      accept Configure (Links : Ids_To_Links) do
         Connected_Routers := Links;
      end Configure;

      declare

         Port_List : constant Connected_Router_Ports := To_Router_Ports (Task_Id, Connected_Routers);

         -----------------------------------------------------------------------
         -- Client Queue Setup
         type Queue_Len is mod 1000;
         package Queue_Pack_Protected_Client is new Queue_Pack_Protected_Generic (Messages_Mailbox, Queue_Len);
         Client_Message_Queue : Queue_Pack_Protected_Client.Protected_Queue;

         --------------------------------------------------------------------

         --------------------------------------------------------------------
         -- Routing Table Setup
         -- Design based on https://www.youtube.com/watch?v=GtgIV8kwqpA&ab_channel=KnowledgeThrusters

         Local_Routing_Table : Routing_Table_Type;
         Local_Routing_Table_Message : Routing_Table_Message;

         Routing_Table_Updated : Boolean := False;

         -- Used to initialise the local routing table and forward it on to neighbours
         task Routing_Table_Setup;
         task body Routing_Table_Setup is
         begin
            -- Init connected routers
            for Port_Id in Port_List'Range loop
               for i in Port_List'Range loop
                  Local_Routing_Table (Port_List (i).Id).Router_ID := Port_List (i).Id; -- Init ID
                  Local_Routing_Table (Port_List (i).Id).Distance := 1; -- Distance = 1
                  Local_Routing_Table (Port_List (i).Id).Next_Hop := Port_List (i).Id; -- Connection = itself
               end loop;
            end loop;

            -- Init other's ID's
            for i in Router_Range loop
               Local_Routing_Table (i).Router_ID := i;
            end loop;

            -- Init the routing message
            Local_Routing_Table_Message.Routing_Table := Local_Routing_Table;
            Local_Routing_Table_Message.Sender := Task_Id;

            -- Send the routing message to neighbours
            for i in Port_List'Range loop
               Port_List (i).Link.all.Receive_Routing_Table_Message (Local_Routing_Table_Message);
            end loop;

         end Routing_Table_Setup;

         task Routing_Table_Updater is
            entry  Routing_Table_Sender_Shutdown;
         end Routing_Table_Updater;

         -- Used to update neighbour's routing tables
         task body Routing_Table_Updater is
            New_Routing_Table_Message  : Routing_Table_Message;
            Shutdown_Indicator : Boolean := False;
         begin

            while not Shutdown_Indicator loop

               select
                  -- If router has shutdown, shutdown
                  accept Routing_Table_Sender_Shutdown do
                     Shutdown_Indicator := True;
                  end Routing_Table_Sender_Shutdown;
               or
                    -- Move on to sending
                  delay 0.0;
               end select;

               -- If our table has been updated send it on
               if Routing_Table_Updated then
                  Routing_Table_Updated := False;

                  New_Routing_Table_Message.Sender := Task_Id;
                  New_Routing_Table_Message.Routing_Table := Local_Routing_Table;
                  for Router of Port_List loop
                     Router.Link.all.Receive_Routing_Table_Message (New_Routing_Table_Message);
                  end loop;

               end if;

            end loop;

         end Routing_Table_Updater;

         --------------------------------------------------------------------
         -- Message Sending Setup
         package Queue_Pack_Protected_Message is new Queue_Pack_Protected_Generic (Router_Message, Queue_Len);
         Messages_To_Send_Queue : Queue_Pack_Protected_Message.Protected_Queue;

         task Message_Sender is
            entry  Message_Sender_Sender_Shutdown;
         end Message_Sender;

         -- Used to update neighbour's routing tables
         task body Message_Sender is
            Message_To_Send  : Router_Message;
            Shutdown_Indicator : Boolean := False;
         begin

            while not Shutdown_Indicator loop

               select
                  -- If router has shutdown, shutdown
                  accept Message_Sender_Sender_Shutdown do
                     Shutdown_Indicator := True;
                  end Message_Sender_Sender_Shutdown;
               or
                  -- Move on to sending
                  delay 0.0;
               end select;

                -- If we have messages to send, send em
               if not Messages_To_Send_Queue.Is_Empty then
                  Messages_To_Send_Queue.Dequeue (Message_To_Send);

                  for i of Port_List loop
                     if i.Id = Local_Routing_Table (Message_To_Send.Destination).Next_Hop then
                        i.Link.all.Receive_Router_Message (Message_To_Send);
                     end if;
                  end loop;

               end if;

            end loop;

         end Message_Sender;
         --------------------------------------------------------------------

      begin

         loop
            --------------------------------------------------------------------
            -- CLIENT INTERFACING
            select

               -- Recieve Message From Client
               accept Send_Message (Message : in Messages_Client) do
                  declare
                     Recieved_Router_Message : Router_Message;
                  begin
                     -- Create new router message from client's message
                     Recieved_Router_Message.Sender := Task_Id;
                     Recieved_Router_Message.Destination := Message.Destination;
                     Recieved_Router_Message.The_Message := Message.The_Message;
                     Recieved_Router_Message.Hop_Counter := 0;

                     -- Put it in the queue to be sent to the next router
                     Messages_To_Send_Queue.Enqueue (Recieved_Router_Message);

                  end;

               end Send_Message;

            or
               -- Provide Message to client if we have one
               when not Client_Message_Queue.Is_Empty =>
                  accept Receive_Message (Message : out Messages_Mailbox) do
                     Client_Message_Queue.Dequeue (Message);
                  end Receive_Message;

            -- END CLIENT INTERFACING
            --------------------------------------------------------------------
            or
            --------------------------------------------------------------------
            -- ROUTER INTERFACING
               accept Receive_Router_Message (Message : in Router_Message) do
                  -- If destination is us, put it in queue for client pickup

                  if Message.Destination = Task_Id then
                     declare
                        New_Client_Message : Messages_Mailbox;

                     begin
                        New_Client_Message.Sender := Message.Sender;
                        New_Client_Message.The_Message := Message.The_Message;
                        New_Client_Message.Hop_Counter := Message.Hop_Counter + 1;
                        Client_Message_Queue.Enqueue (New_Client_Message);
                     end;
                  else
                  -- Otherwise send it to the next router depending on the routing table

                     declare
                        New_Message : Router_Message := Message;
                     begin
                        -- Update hop counter and send the message on
                        New_Message.Hop_Counter := New_Message.Hop_Counter + 1;

                        -- Put it in the queue to be send
                        Messages_To_Send_Queue.Enqueue (New_Message);

                     end;
                  end if;

               end Receive_Router_Message;

            or

               -- ROUTER TABLE MESSAGES
               -- Based on:
                 -- [1] Routing table Design: https://www.youtube.com/watch?v=GtgIV8kwqpA&ab_channel=KnowledgeThrusters
                 -- [2] Routing table Updating: https://www.geeksforgeeks.org/distance-vector-routing-dvr-protocol/
               accept Receive_Routing_Table_Message (Message : in Routing_Table_Message) do
                  -- Loop through values in the received table
                  for Router_ID in Message.Routing_Table'Range loop
                     -- Check if the router has a path to the current index and it's not us
                     if Message.Routing_Table (Router_ID).Distance /= Natural'Invalid_Value and then Message.Routing_Table (Router_ID).Router_ID /= Task_Id then
                        -- Based on B-F equation from [2]: Dx(y) = min { C(x,v) + Dv(y), Dx(y) }
                        -- If we dont have a path take theirs
                        if Local_Routing_Table (Router_ID).Distance = Natural'Invalid_Value then
                           Local_Routing_Table (Router_ID).Distance := Message.Routing_Table (Router_ID).Distance + 1;
                           Local_Routing_Table (Router_ID).Next_Hop := Message.Sender;
                           -- Tell routing table sender it needs to send
                           Routing_Table_Updated := True;
                        -- If we do have a path but its longer than theirs take theirs (min (C(x,v) + Dv(y), Dx(y))
                        elsif Local_Routing_Table (Router_ID).Distance > Message.Routing_Table (Router_ID).Distance + 1 then
                           Local_Routing_Table (Router_ID).Distance := Message.Routing_Table (Router_ID).Distance + 1;
                           Local_Routing_Table (Router_ID).Next_Hop := Message.Sender;
                           -- Tell routing table sender it needs to send
                           Routing_Table_Updated := True;
                        end if;
                        -- Otherwise we already have best path
                     end if;
                  end loop;

               end Receive_Routing_Table_Message;

            -- END ROUTER INTERFACING
            --------------------------------------------------------------------

            or

               accept Shutdown;

               -- Shutdown the sending tasks
               Routing_Table_Updater.Routing_Table_Sender_Shutdown;
               Message_Sender.Message_Sender_Sender_Shutdown;

               exit;

            end select;

         end loop;

      end;

   exception
      when Exception_Id : others => Show_Exception (Exception_Id);
   end Router_Task;

end Generic_Router;
