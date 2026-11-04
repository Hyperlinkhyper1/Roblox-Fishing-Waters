-- Deterministic RemoteFunction yields exercise the production paint queue.
local checks=0
local function check(value,message) assert(value,message);checks+=1 end
local function deep(value)
	if type(value)~='table' then return value end
	local result={};for key,child in value do result[key]=deep(child) end;return result
end
local threads={}
local task={}
local clock=0
local os={clock=function() return clock end}
function task.wait(seconds) clock+=seconds or 0;return seconds end
function task.spawn(callback,...)
	local thread=if type(callback)=='thread' then callback else coroutine.create(callback)
	table.insert(threads,thread)
	local ok,reason=coroutine.resume(thread,...);assert(ok,reason)
	return thread
end
local Queue=(function()
-- BUILD_PAINT_QUEUE --
end)()
local sends,changed,results={}, {}, {}
local function sender(entries)
	local send={Entries=deep(entries),Thread=coroutine.running()}
	table.insert(sends,send)
	return coroutine.yield('paint acknowledgement')
end
local queue=Queue.new({Send=sender,Changed=function(outstanding) table.insert(changed,deep(outstanding)) end,
	Result=function(result,remaining) table.insert(results,{Result=result,Remaining=deep(remaining)}) end})
local function paint(id,red)
	queue:paint({Id=id,Material='Brick',Color={red,50,60}})
end
local function ack(index,ok)
	local send=assert(sends[index],'No paint batch is waiting')
	local response=if type(ok)=='table' then ok else {Ok=ok~=false,State={Pieces={},Overrides={}}}
	local resumed,reason=coroutine.resume(send.Thread,response)
	assert(resumed,reason)
end

paint('p1',10)
check(queue:busy() and #sends==1,'A paint must submit immediately without waiting for a frame timer')
paint('p2',20)
paint('p1',30)
paint('p1',40)
check(#sends==1,'Fast clicks must queue behind one RemoteFunction rather than overlap saves')
local outstanding=changed[#changed]
check(outstanding.p1.Patch.Color[1]==40 and outstanding.p2.Patch.Color[1]==20,'Latest paint per target must remain visible while the previous save waits')
local drained=0
queue:drain(function() drained+=1 end)
check(drained==0,'Undo or another edit must wait for all preceding paint batches')
ack(1)
check(#sends==2 and #sends[2].Entries==2,'A saved first click must flush all queued targets as one batch')
local second={}
for _,entry in sends[2].Entries do second[entry.Id]=entry end
check(second.p1.Color[1]==40 and second.p2.Color[1]==20,'Intermediate colors must coalesce to the last clicked finish')
check(results[1].Remaining.p1.Patch.Color[1]==40,'An acknowledgement must leave newer optimistic paint outstanding')
ack(2)
check(not queue:busy() and drained==1,'Draining must resume exactly once after the final save')
check(next(changed[#changed])==nil,'A completed save must release all optimistic overlays')

-- Bounded batches avoid growing one remote packet without limit.
local start=#sends
paint('bulk0',1)
for index=1,70 do paint('bulk'..index,index) end
check(#sends==start+1,'A rapid stroke must keep only one in-flight save')
ack(start+1)
check(#sends==start+2 and #sends[start+2].Entries==64,'A batch must contain at most 64 target finishes')
ack(start+2)
check(#sends==start+3 and #sends[start+3].Entries==6,'Overflow targets must remain queued for the next batch')
ack(start+3)
check(not queue:busy(),'A long stroke must eventually drain completely')

-- A rejected older finish must not discard a later click on the same target.
start=#sends
paint('p3',80)
paint('p3',90)
ack(start+1,false)
check(results[#results].Result.Ok==false,'Save failures must be reported to the client for rollback')
check(results[#results].Remaining.p3.Patch.Color[1]==90,'Rejected paint must preserve a newer queued finish for the same target')
check(#sends==start+2 and sends[start+2].Entries[1].Color[1]==90,'The newer finish must still be submitted after an earlier rejection')
ack(start+2)
check(not queue:busy(),'A failed earlier save must not leave the painting queue stuck')
queue:drain(function() drained+=1 end)
check(drained==2,'Draining an idle queue must run immediately')
start=#sends
local oldResults,oldClock=#results,clock
paint('p4',110)
ack(start+1,{Ok=false,Message='Paint rate limit',RetryAfter=0.2})
check(#sends==start+2 and sends[start+2].Entries[1].Id=='p4','A transient paint rate limit must retry the same target')
check(queue:busy() and queue.Outstanding.p4.Patch.Color[1]==110,'Rate backoff must keep the optimistic finish visible')
check(#results==oldResults and clock>=oldClock+0.2,'Rate backoff must wait without reporting a rejected paint or clearing its overlay')
ack(start+2)
check(not queue:busy(),'Painting must resume and drain after a rate-limited batch succeeds')
print('Build paint queue: '..checks..' delayed-save, rapid-click, coalescing, batching, rejection and drain checks passed.')
