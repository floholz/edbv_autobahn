function dist = distance(x1, y1, width1, height1, x2, y2, width2, height2)

   if (bboxOverlapRatio([x1 y1 width1 height1], [x2 y2 width2 height2])~=0)
       dist = 0;
   else
   
   width1 = width1+x1;
   height1 = height1+y1;
   width2 = width2+x2;
   height2 = height2+y2;
       
   left = width2 < x1;
   right = width1 < x2;
   bottom = height2 < y1;
   top = height1 < y2;
   
   if (top && left)
       dist = calcDistance(x1, height1, width2, y2);
   elseif (left && bottom)
       dist = calcDistance(x1, y1, width2, height2);
   elseif (bottom && right)
       dist = calcDistance(width1, y1, x2, height2);
   elseif (right && top)
       dist = calcDistance(width1, height1, x2, y2);
   elseif (left)
       dist = x1 - width2;
   elseif (right)
       dist = x2 - width1;
   elseif (bottom)
       dist = y1 - height2;
   elseif (top)
       dist = y2 - height1;
   else
       dist = 0;
   end
   end
end

function dist = calcDistance(x1, y1, x2, y2)
    dist = sqrt(double((x2-x1)^2+(y2-y1)^2));
end