if(getRversion() >= "3.1.0") utils::globalVariables(c("myLoad","probe.features","bloodCtl"))

champ.CNA <-
function(intensity=myLoad$intensity, pd=myLoad$pd, loadFile=FALSE, batchCorrect=TRUE, file="intensity.txt", resultsDir=paste(getwd(),"resultsChamp",sep="/"), sampleCNA=TRUE,plotSample=TRUE, filterXY=TRUE, groupFreqPlots=TRUE,freqThreshold=0.3, control=TRUE, controlGroup="Control",arraytype="450K")
{
    if(arraytype=="EPIC"){
        data(probe.features.epic)
    }else{
        data(probe.features)
    }
	normalize.quantiles<-NULL
    rm(normalize.quantiles)
	control.intsqnlog<-NULL
	CNA<-NA
	rm(CNA)
	smooth.CNA<-NA
	rm(smooth.CNA)
	segment<-NA
	rm(segment)
	
	message("Run champ.CNA")
	newDir=paste(resultsDir,"CNA",sep="/")
    
	if(!file.exists(resultsDir)){dir.create(resultsDir)}
	if(!file.exists(newDir))
	{
		dir.create(newDir)
	}
		
	if(loadFile)
	{
		ints = read.table(file,row.names =T, sep = "\t")
        if(filterXY)
        {
            autosomes=probe.features[!probe.features$CHR %in% c("X","Y"), ]
            ints=ints[row.names(ints) %in% row.names(autosomes), ]
        }
	}else
	{
		ints=intensity
	}
	
	if(control)
	{
		        	
        if(controlGroup != "champCtl" & !(controlGroup %in% pd$Sample_Group))
        {
        	message("You have chosen ", controlGroup, " as the reference and this does not exist in your sample sheet (column Sample_Group). The analysis will run with ChAMP blood controls.")
        	controlGroup="champCtl"
        }
        
        if(controlGroup == "champCtl")
        {
            #load("champBloodCtls.Rdata")
            data(champBloodCtls)
            ctlIntensity=bloodCtl$intensity
            ctlIntensity=ctlIntensity[which(row.names(ctlIntensity) %in% row.names(ints)),]
		
            ints=cbind(ints,ctlIntensity)
            pd=rbind(pd,bloodCtl$pd)
            batchCorrect=F
        }
	}
	
	#Extracts names of samples 
	names<-colnames(ints)

	#Quantile normalises intensities	
	intsqn<-normalize.quantiles(as.matrix(ints))
	colnames(intsqn)<-names


	#Calculates Log2
	intsqnlog<-log2(intsqn)
    	
	if(batchCorrect)
	{
		message("Run batch correction for CNA")
		combat=champ.runCombat(beta.c=intsqnlog,pd=pd,logitTrans=FALSE)
		intsqnlog=combat$beta
	}

	if(control)
	{
        	#separates case from control(reference sample/samples)        	
        	message("champ.CNA is using the samples you have defined as ", controlGroup," as the reference for calculating copy number aberrations.")
        	if(controlGroup=="champCtl")
        	{
        		message("As you are using the ChAMP controls Combat cannot adjust for batch effects. Batch effects may affect your dataset.")
        	}
        
        	
        	controlSamples= pd[which(pd$Sample_Group==controlGroup),]
        	caseSamples= pd[which(pd$Sample_Group != controlGroup),]
		case.intsqnlog<-intsqnlog[,which(colnames(intsqnlog) %in% caseSamples$Sample_Name)]
	        control.intsqnlog<-intsqnlog[,which(colnames(intsqnlog) %in% controlSamples$Sample_Name)]
       	 	control.intsqnlog<-rowMeans(control.intsqnlog)
        
        	intsqnlogratio<-case.intsqnlog
        	for(i in 1:ncol(case.intsqnlog))
        	{
            		intsqnlogratio[,i]<-case.intsqnlog[,i]-control.intsqnlog
        	}
			
	}else
	{
			message("champ.CNA is using an average of all your samples as the reference for calculating copy number aberrations.")
			#Creates alternate reference sample from rowMeans if proper reference /control is not available 
			case.intsqnlog<-intsqnlog[,1:length(names)]
			ref.intsqnlog<-rowMeans(intsqnlog)
   
        	intsqnlogratio<-intsqnlog
        	for(i in 1:ncol(case.intsqnlog))
        	{
            		intsqnlogratio[,i]<-case.intsqnlog[,i]-ref.intsqnlog
        	}
	}

	ints <- data.frame(ints, probe.features$MAPINFO[match(rownames(ints), rownames(probe.features))])
	names(ints)[length(ints)] <- "MAPINFO"
	ints <- data.frame(ints, probe.features$CHR[match(rownames(ints), rownames(probe.features))])
	names(ints)[length(ints)] <- "CHR"

	#Replaces Chr X and Y with 23 and 24
	levels(ints$CHR)[levels(ints$CHR)=='X']='23'
	levels(ints$CHR)[levels(ints$CHR)=='Y']='24'

	#converts CHR factors to numeric 
	CHR<-as.numeric(levels(ints$CHR))[ints$CHR]

	#need to copy in MAPINFO
	ints$MAPINFO<-as.numeric(ints$MAPINFO)
	MAPINFO=probe.features$MAPINFO[match(rownames(ints), rownames(probe.features))]
	MAPINFO<-as.numeric(MAPINFO)

	#Runs CNA and generates individual DNA Copy Number profiles
	if(sampleCNA)
	{
		message("Saving Copy Number information for each Sample")
		for(i in 1:ncol(case.intsqnlog))
		{
			CNA.object <- CNA(cbind(intsqnlogratio[,i]), CHR, MAPINFO ,data.type = "logratio", sampleid = paste(colnames(case.intsqnlog)[i],"qn"))
			smoothed.CNA.object <- smooth.CNA(CNA.object)
			segment.smoothed.CNA.object <- segment(smoothed.CNA.object, verbose = 1,alpha=0.001, undo.splits="sdundo", undo.SD=2)
			if(plotSample)
			{
				imageName<-paste(colnames(case.intsqnlog)[i],"qn.jpg",sep="")
				imageName=paste(newDir,imageName,sep="/")
				jpeg(imageName)
				plot(segment.smoothed.CNA.object, plot.type = "w", ylim=c(-6,6))
				dev.off()
			}
			seg<-segment.smoothed.CNA.object$output
			table_name<-paste(newDir,"/",colnames(case.intsqnlog)[i],"qn.txt",sep="")
			write.table(seg,table_name, sep="\t", col.names=T, row.names=F, quote=FALSE)
		}
	}
	
	##group Frequency plots
	if(groupFreqPlots)
	{
	message("Saving frequency plots for each group")
        
        if(control)
        {
            groups = unique(pd$Sample_Group)
	    groups = groups[!groups==controlGroup]
        }else
        {
            groups = unique(pd$Sample_Group)
        }
	
		for(g in 1:length(groups))
		{
		
			pd_group = pd[which(pd$Sample_Group==groups[g]),]
			data_group=intsqnlogratio[,which(colnames(intsqnlogratio) %in% pd_group$Sample_Name)]
			ints_group=ints[,which(colnames(ints) %in% pd_group$Sample_Name)]
			row.names(ints_group)=row.names(ints)
	
			group.CNA.object <- CNA(data_group, CHR, MAPINFO,data.type = "logratio", sampleid = paste(paste(pd_group$Sample_Name,pd_group$Sample_Group),"qn"))
			group.smoothed.CNA.object <- smooth.CNA(group.CNA.object)
			group.segment.smoothed.CNA.object <- segment(group.smoothed.CNA.object, verbose = 1,alpha=0.001, undo.splits="sdundo", undo.SD=2)
		
			group.freq = glFrequency(group.segment.smoothed.CNA.object,freqThreshold)		
	
			#begin plot
			ints = ints[order(ints$CHR,ints$MAPINFO),]
			labels_chr <- data.matrix(summary(as.factor(ints$CHR)))

			test1<- data.frame(labels_chr,row.names(labels_chr) )
			test <- data.frame(unique(CHR))
			colnames(test) = c("chr")
			colnames(test1) = c("count","chr")
			F1 <- merge(test,test1, by="chr", sort=T)
			for(i in 2:length(row.names(F1))){F1[i,2] = F1[i-1,2] + F1[i,2] ; }

			F1$label <- NULL ; F1[1,3] <- F1[1,2] / 2 ;	
			for (i in 2:length(row.names(F1))){ F1[i,3] <- (F1[i,2]+F1[i-1,2])/2; }
	
			y1=group.freq$gain
			y2=group.freq$loss

			imageName1=paste(groups[g],"_","FreqPlot.pdf",sep="")
			imageName1=paste(newDir,imageName1,sep="/")
			graphTitle = paste("Frequency Plot of ",groups[g]," Samples",sep="")
		
			pdf(imageName1, width = 10.0, height = 9.0)
		
			#plot gain
			plot(y1, type='h',  xaxt="n",  yaxt="n", col="green", main = graphTitle , ylim=range(-1, 1), xlab='Chromosome Number',  ylab=paste('Fraction of Samples with Gain or Loss (n=',dim(data_group)[2],")",sep=""),xaxs = "i", yaxs = "i")

			#plot loss
			points(y2, type='h', col="red")

			#label for chromosomes
			x= c(-1,-0.8,-0.6,-0.4,-0.2,0,0.2,0.4,0.6,0.8,1)
			y= c(1:length(F1[,2]))
			axis(1, at = c(F1[,2]), labels =FALSE, tick = TRUE, las = 1, col = "black", lty = "dotted", tck = 1 );
			axis(1, at = c(F1[,3]), labels =F1$chr, tick = FALSE );
			axis(2, at = c(x), labels=x, tick = TRUE, las = 1, col = "black", lty = "dotted", tck = 1 );
			dev.off()
		}
	}

}
