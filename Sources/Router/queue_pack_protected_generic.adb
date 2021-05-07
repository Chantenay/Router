--
-- Uwe R. Zimmer, Australia, 2014
--
-- Taken from lab 1/2

package body Queue_Pack_Protected_Generic is

   protected body Protected_Queue is

       function Is_Empty return Boolean is (Queue.Is_Empty);

      function Is_Full return Boolean is (not Queue.Is_Empty and then Queue.Top = Queue.Free);

      entry Enqueue (Item : Element) when not Is_Full is

      begin
         Queue.Elements (Queue.Free) := Item;
         Queue.Free     := Index'Succ (Queue.Free);
         Queue.Is_Empty := False;
      end Enqueue;

      entry Dequeue (Item : out Element) when not Is_Empty is

      begin
         Item           := Queue.Elements (Queue.Top);
         Queue.Top      := Index'Succ (Queue.Top);
         Queue.Is_Empty := Queue.Top = Queue.Free;
      end Dequeue;

   end Protected_Queue;
end Queue_Pack_Protected_Generic;
