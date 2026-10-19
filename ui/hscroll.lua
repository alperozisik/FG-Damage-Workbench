local trackWidth,maximum,current,thumbWidth=0,0,0,0;
local grab;
function configure(width,limit,value)
  trackWidth=width; maximum=limit; current=value;
  setVisible(maximum>0);
  thumbWidth=math.max(32,math.floor(width*width/(width+maximum)));
  local left=maximum>0 and current/maximum*(width-thumbWidth) or 0;
  window.scrollhandle.setVisible(maximum>0);
  window.scrollhandle.setStaticBounds(44+left,(window.getPlan().phase=="results" and 814 or 444)+2,thumbWidth,10);
end
function thumbOffset() return maximum>0 and current/maximum*(trackWidth-thumbWidth) or 0; end
function move(x)
  if maximum<=0 then return; end
  local left=math.max(0,math.min(trackWidth-thumbWidth,x-(grab or thumbWidth/2)));
  window.setScrollOffset(left/math.max(1,trackWidth-thumbWidth)*maximum);
end
function onClickDown(button,x,y)
  if button~=1 then return true; end
  local left=maximum>0 and current/maximum*(trackWidth-thumbWidth) or 0;
  grab=(x>=left and x<=left+thumbWidth) and x-left or thumbWidth/2;
  move(x); return true;
end
function onClickRelease(button,x,y) grab=nil; return true; end
function onDragStart(button,x,y,drag) if button==1 then move(x); end return true; end
function onDrag(button,x,y,drag) if button==1 then move(x); end return true; end
function onDragEnd() grab=nil; end
function onWheel(notches) window.scrollZones(-notches*32); return true; end
