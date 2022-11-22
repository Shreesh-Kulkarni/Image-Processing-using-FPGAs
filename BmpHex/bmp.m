b=imread('test.bmp'); % reading the image file
k=1;
for i=512:-1:1 % loop for reading image and writing to the output image
for j=1:768
a(k)=b(i,j,1);
a(k+1)=b(i,j,2);
a(k+2)=b(i,j,3);
k=k+3;
end
end
fid = fopen('test.hex', 'wt'); % new output file
fprintf(fid, '%x\n', a);
disp('file writing done, you can close window now');disp(' ');
fclose(fid);
