# qMorph
<I>Igor code for quantification of reconstructed neuronal morphologies</I>

  <BR><B>QUANTIFY MORPHOLOGY</B>
<BR>by Jesper Sjöström, begun 7 Nov 2010
<BR>Reads folders of SWC files, where each folder corresponds to one condition, and averages those.
<BR>See <A HREF="http://www.sciencedirect.com/science/article/pii/S089662731200579X" target="_NEW">Buchanan et al Neuron 2012<A> for application.
  <BR><BR><B><I>Quick instructions</I></B>
<BR>First run "Set up qMorph", then run "Make reconstruction analysis panel"
<BR>Populate LayerMappingTable with relevant data for layers, scaling, etc
<BR>Populate Rotation table to align slanted reconstructions with the right side up (e.g. apical dendrite)
<BR>LayerMappingTable is required, while Rotation table is optional.
<BR><BR>This code requires Jesper's Tools v3, JespersTools_v03.ipf, to be located in /Igor Procedures/.

<I>R code for Statistical analysis of Sholl profiles based on mixed-effect models</I>
<BR><B>STATS ON SHOLL PROFILES</B>
<BR>Run "Sholl_LMER.R" using e.g. data in "DataFiles.zip"
<BR>Sample output is found in "PValueFiles.zip"
<BR>Code adapted by Shawniya Alageswaran from
<BR>Wilson, M. D., Sethi, S., Lein, P. J. & Keil, K. P.
<BR><I>Valid statistical approaches for analyzing sholl data: Mixed effects
<BR>versus simple linear models.</I> <B>Journal of Neuroscience Methods</B> 279, 33-43 (2017).

