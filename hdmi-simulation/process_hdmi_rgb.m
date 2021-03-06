function [R1,G1,B1,R2,G2,B2] = process_hdmi_rgb(R1,G1,B1,R2,G2,B2)
    [R1,G1,B1] = process_hdmi_1(R1,G1,B1);
    [R2,G2,B2] = process_hdmi_1(R2,G2,B2);
end

function [R,G,B] = process_hdmi_1(R,G,B)
    global HDMI_PROCESS_YUV_BLUR_SHARPEN, global HDMI_PROCESS_YUV_NOISE, global HDMI_PROCESS_RGB_COMPRESS

    % clip the input image to 16-235
    R = min(max(R,16),235);
    G = min(max(G,16),235);
    B = min(max(B,16),235);

    if ~HDMI_PROCESS_RGB_COMPRESS || HDMI_PROCESS_YUV_BLUR_SHARPEN || HDMI_PROCESS_YUV_NOISE
        % convert the image to YUV422 8-bit (16-235)
        [Y,U,V] = rgb2yuv422(R,G,B);
       
        % simulate some image filters that might be applied during recording
        if HDMI_PROCESS_YUV_BLUR_SHARPEN
            Y = imfilter(Y, fspecial('disk',1));
            Y = imfilter(Y, fspecial('unsharp'));
            U = imfilter(U, fspecial('disk',1));
            V = imfilter(V, fspecial('disk',1));
        end
       
        if HDMI_PROCESS_YUV_NOISE
           Y = uint8(double(Y) + randn(size(Y)));
           U = uint8(double(U) + randn(size(U)));
           V = uint8(double(V) + randn(size(V)));
        end
       
        % back to 8-bit RGB
        [R,G,B] = yuv4222rgb(Y,U,V);
    end
    
    if HDMI_PROCESS_RGB_COMPRESS
        RGB(:,:,1) = uint8(R);
        RGB(:,:,2) = uint8(G);
        RGB(:,:,3) = uint8(B);
        % use ProRes profile 2 (standard)
        % assume input range 16-235
        imwrite(RGB, 'tmp.ppm');
        system('ffmpeg -i tmp.ppm -color_range 1 -vcodec prores -profile:v 2 -y tmp.mov');
        system('ffmpeg -i tmp.mov -color_range 1 -pix_fmt rgb24 -y tmp.ppm');
        RGB = imread('tmp.ppm');
        R = RGB(:,:,1);
        G = RGB(:,:,2);
        B = RGB(:,:,3);
    end
    
    % expand the output to 0-255
    % (that's how our HDMI recorder seems to behave)
    R = double(R);
    G = double(G);
    B = double(B);
    R = (R - 16) * 255 / (235 - 16);
    G = (G - 16) * 255 / (235 - 16);
    B = (B - 16) * 255 / (235 - 16);
    R = uint8(R);
    G = uint8(G);
    B = uint8(B);
end

function [Y,U,V] = rgb2yuv422(R,G,B)
    % input range: 0-255
    % output range: 16-235 for Y, 16-240 for U,V
    RGB(:,:,1) = uint8(R);
    RGB(:,:,2) = uint8(G);
    RGB(:,:,3) = uint8(B);
    YCBCR = rgb2ycbcr(RGB);
    Y = YCBCR(:,:,1);
    U = YCBCR(:,:,2);
    V = YCBCR(:,:,3);
    U = imresize(U, [size(U,1) size(U,2)/2]);
    V = imresize(V, [size(V,1) size(V,2)/2]);
end

function [R,G,B] = yuv4222rgb(Y,U,V)
    % input range: 16-235 for Y, 16-240 for U,V
    % output range: 0-255
    U = imresize(U, [size(U,1) size(U,2)*2]);
    V = imresize(V, [size(V,1) size(V,2)*2]);
    YCBCR(:,:,1) = uint8(Y);
    YCBCR(:,:,2) = uint8(U);
    YCBCR(:,:,3) = uint8(V);
    RGB = ycbcr2rgb(YCBCR);   
    R = RGB(:,:,1);
    G = RGB(:,:,2);
    B = RGB(:,:,3);
end
