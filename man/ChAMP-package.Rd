\name{ChAMP-package}
\alias{ChAMP-package}
\alias{ChAMP}
\docType{package}
\title{
ChAMP-Chip Analysis Methylation Pipeline
}
\description{
A pipeline that enables pre-processing of 450k data, a selection of normalization methods and novel methods for downstream analysis including Probe Lasso DMR Hunter and Copy Number Alteration analysis.
}
\details{
\tabular{ll}{
Package: \tab ChAMP\cr
Type: \tab Package\cr
Version: \tab 1.9.2\cr
Date: \tab 2016-03-13\cr
License: \tab GPL-3\cr
}
The full analysis pipeline can be run with all defaults using champ.process()

Alternatively, it can be run in steps using all functions separately.
}

\author{
Tiffany Morris, Lee Stirling, Andy Feber, Andrew Teschendorff, Ankur Chakravarthy, Yuan Tian, Stephen Beck\cr
\bold{Maintainer}: Yuan Tian, Tiffany Morris <champ450k@gmail.com>
}
\keyword{ package }
\keyword{ methylation}
\keyword{ HumanMethylation450 }
\keyword{ 450k }
\keyword{ array }
\keyword{ Beadchip }
\keyword{ DNAMethylation }
\keyword{ Epic }
\examples{
\donttest{
	directory=system.file('extdata',package='ChAMPdata')
	champ.process(directory=directory)
	myLoad=champ.load()
	myNorm=champ.norm()
    myRefBase=champ.refbase()
	champ.SVD()
	batchNorm=champ.runCombat()
	limma=champ.MVP()
	myDMR=champ.DMR()
	champ.CNA()
	}
}
