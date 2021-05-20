# qMorph
Igor code for quantification of reconstructed neuronal morphologies
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	QUANTIFY MORPHOLOGY
////	by Jesper Sjöström, begun 7 Nov 2010
////	Reads folders of SWC files, where each folder corresponds to one condition, and averages those.
////	See Buchanan et al Neuron 2012 for application
////	First run "Set up qMorph", then run "Make reconstruction analysis panel"
////	Populate LayerMappingTable with relevant data for layers, scaling, etc
////	Populate Rotation table to align slanted reconstructions with the right side up (e.g. apical dendrite)
////	LayerMappingTable is required, while Rotation table is optional.
////	This code requires Jesper's Tools v3, JespersTools_v03.ipf, to be located in /Igor procedures/.
////////////////////////////////////////////////////////////////////////////////////////////////////////////
