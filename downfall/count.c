#include <stdio.h>
#include <stdlib.h>     /* strtol */

/*
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
ssize_t read(int fd, void *buf, size_t count);
*/

char * charToBitStr(char *bs, u_int8_t c){
    int i=0;
    for(unsigned int mask = 0x80; mask; mask >>= 1) {
         bs[i++] = '0' + !!( mask & c );
    }
    bs[i]=0; // null
    return bs;
}

int main(int argc, char *argv[])
{
    FILE* fpIn=stdin;
    FILE* fpJson=fopen("./out.json","w");
    int stride=8;
    int totalBytesPerSample=(0x01<<atoi(argv[1]));
    int sampleSum=0; 
    int bytesRead=0;
    u_int8_t c;
    char buf[10];
    u_int32_t sum;                /* max_sum=8*128=2048 */
    u_int32_t sums[2048]={0};
    u_int32_t bins[16]={0};       /* 2048/16 = 128 equivalent events per bin */
    
    while(bytesRead < totalBytesPerSample)
    {
        sum=0;
        fprintf(stderr,"%4x: ",bytesRead);
        for (int i=0; i<stride;i++)
        {
            fread(&c,1, 1, fpIn);
            bytesRead++;
            sum = sum + c;
            sampleSum+=c;
            charToBitStr(buf,c);
            fprintf(stderr, "%02x:%s ", c, buf );
        }
        sums[sum]=sums[sum]+1;
        fprintf(stderr,"Sum: %d, avg: %d\n",sum,sum/stride);
    } 
    /* reduce 2048 possible sum values after adding 8 8 bit numbers
     * into 16 bins of 128 possible sum values.
     *
     * bin[0] = sum of marks in 0-127
     * bin[1] = sum of marks in 128-255
     * ...
     * bin[15] = sum of marks in 1920-(2048-8)
     */
    for(int i=0;i<16;i++){
        for(int j=0;j<128;j++){
            bins[i]=bins[i]+sums[i*128+j];
        }
        printf("%5d ",bins[i]);
    }
   
    printf("\n");

    /* n choose k, e.g. 16 choose 1, 2, 3 ... */
    int num = 1;
    for (int k = 0; k < 16; k++) {
        if(k!=0) num = num * (16 - k + 1) / k;
        printf("%5d ", num);
    }
    printf("\n");

    num = 1;
    for (int k = 0; k < 16; k++) {
        printf("%5d ", k*128);
    }
    printf("\n");


    for (int k =0 ; k <= 16; k++) {
       printf("%5d ", k);
    }
  
    printf("\n");

    printf("bytes read: %8d, sampleSum=%5d, avg:%5d, expected: %5d\n",
            bytesRead,
            sampleSum,
            sampleSum/bytesRead, 
            128);
   
    fprintf(fpJson,"{\n");

    for (int i =0 ; i < 2047; i++) {
       fprintf(fpJson,"\"%d\":%d,\n", i,sums[i]);
    }  
    fprintf(fpJson,"\"%d\":%d\n", 2047,sums[2047]);
    fprintf(fpJson,"}\n");
    return 0;
}
