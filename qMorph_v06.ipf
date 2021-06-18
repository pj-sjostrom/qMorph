#pragma rtGlobals=1		// Use modern global access method.
#include  <SaveGraph>
#include <fuzzyClasses>

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	QUANTIFY MORPHOLOGY
////	by Jesper Sjšstršm, begun 7 Nov 2010
////	Reads folders of SWC files, where each folder corresponds to one condition, and averages those.
////	See Buchanan et al Neuron 2012 for application
////	First run "Set up bugfix
", then run "Make reconstruction analysis panel"
////	Populate LayerMappingTable with relevant data for layers, scaling, etc
////	Populate Rotation table to align slanted reconstructions with the right side up (e.g. apical dendrite)
////	LayerMappingTable is required, while Rotation table is optional.
////	This code requires Jesper's Tools v3, JespersTools_v03.ipf, to be located in /Igor procedures/.
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	¥	Changed the way the soma compartments are read. If there is no soma tag, then use the critical 
////		diameter like before, otherwise use the soma tag.
////	Jesper, 2013-05-23
////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	¥	Tidied up dependencies of code for Libin Zhou's manuscript in Scientific Reports. Removed need for
////		Cluster_v01.ipf, which was found in qMorph_v03.ipf.
////	Jesper, 2021-05-19
////////////////////////////////////////////////////////////////////////////////////////////////////////////

//	AxonCompType = 2
//	DendrCompType = AxonCompType+1

Menu "Macros"
	"Set up qMorph",SetUpMorph()
	"Make reconstruction analysis panel",Make_Recon_Panel()
	"Reload all reconstructions in all folders",ReloadAll()
	"Load all reconstructions in a folder",LoadReconFolder("")
	"Load single reconstruction",LoadRecon()
	SubMenu "Remember conditions"
		"Add to list",AddToList()
		"Review List",ReviewList()
		"Kill List",KillList()
	End
	SubMenu "Organize"
		"Rotation table to front",RotTableToFront()
		"Layer mapping table to front",LayerMapTableToFront()
		"Graphs to front",GraphsToFront()
		"Tables to front",TheTablesToFront()
		"Tables to back",TheTablesToBack()
		"Spread reconstruction traces laterally",SpreadReconsLaterally()
	End
	SubMenu "Tweaks"
		"Toggle align on soma vs align on L4-L5 boundary",ToggleAlignOnL4L5()
		"Toggle show axons",qM_toggleNoAxon()
		"Set matrix X and Y limits",qM_CreateMatrixLimitsTable()
		"Reblend matrix maps",ReBlend()
		"Make background black",MakeBackGroundBlack()
		"Make background white",MakeBackGroundWhite()
		"Make background black for PV pooled",MakeBackGroundBlackPV()
	End
	SubMenu "Stats"
		"Do stats comparing all stored data",ReconStatistics(-1)
		"Do stats comparing all four types",ReconStats()
		"Do stats comparing all three types {pool PV}",ReconStats2()
	End
	"-"

End

// quickFind:
// AnalyzeRecon
// Make_Recon_Panel

Function qM_toggleNoAxon()

	if (Exists("qM_noAxon")==0)
		Variable/G qM_noAxon = 1
	else
		NVAR qM_noAxon
		if (qM_noAxon)
			qM_noAxon = 0
		else
			qM_noAxon = 1
		endif
	endif

	if (qM_noAxon)
		print "Axon compartments will NOT be included in maps."
	else
		print "Axon compartments WILL be included in maps."
	endif

End

Function qSave()

	SVAR	fName
	SVAR	pathName

	SavePICT/O/E=-2 as pathName+fName+".pdf"

End

Function AddToList()

	SVAR	typeName

	if (!(Exists("typeList")))
		KillList()
	endif
	
	SVAR	typeList
	
	Print "Adding "+typeName+" to list..."
	typeList += typeName+";"
	ReviewList()

End

Function ReviewList()

	SVAR	typeList
	
	Print "List is now: ",typeList

End

Function KillList()

	Print "Empty list"

	String/G	typeList = ""

End

Function TheTablesToFront()

	SVAR		typeList
	
	String		ListOfTables = ""

	Variable	n = ItemsInList(typeList)
	Variable	i
	i = 0
	do
		DoWindow/F $("theTable_"+StringFromList(i,typeList))
		ListOfTables += "theTable_"+StringFromList(i,typeList)+";"
		i += 1
	while(i<n)

	JT_ArrangeGraphs(ListOfTables)

End

Function TheTablesToBack()

	SVAR		typeList
	
	Variable	n = ItemsInList(typeList)
	Variable	i
	i = 0
	do
		DoWindow/B $("theTable_"+StringFromList(i,typeList))
		i += 1
	while(i<n)

End

Macro SetUpMorph()
	PauseUpdate; Silent 1		// building window...
	
	Variable/G		AlignOnL4L5 = 1
	Variable/G		SomaByDiam = 1
	Variable/G		whatIsCompSize = 2
	CreateMatrices()
	
	if (Exists("wReconFileName")==0)
		Make/O/T/N=(0) wReconFileName,wLayerFileName,wExtentFileName,RotateWhich
		Make/O/N=(0) wPixPerMicron,NMDASupp,RotateHowMuch
	endif
	
	LayerMappingTable()
	Rotation_table()
	CreateGlobalVars()

EndMacro

Window LayerMappingTable() : Table
	PauseUpdate; Silent 1		// building window...
	DoWindow/K LayerMappingTable
	Edit/W=(71,148,973,666) wReconFileName,wLayerFileName,wPixPerMicron,NMDASupp,wExtentFileName as "LayerMappingTable"
	ModifyTable format(Point)=1,width(wReconFileName)=300,width(wLayerFileName)=160
	ModifyTable width(wPixPerMicron)=90,width(wExtentFileName)=172
	nw("LayerMappingTable")
EndMacro


Window Rotation_table() : Table
	PauseUpdate; Silent 1		// building window...
	DoWindow/K Rotation_table
	Edit/W=(652,338,1164,821) RotateWhich,RotateHowMuch as "Rotation table"
	ModifyTable format(Point)=1,width(RotateWhich)=240,width(RotateHowMuch)=94
	nw("Rotation table")
EndMacro

Function ToggleAlignOnL4L5()

	NVAR		AlignOnL4L5
	
	if (AlignOnL4L5)
		AlignOnL4L5 = 0
		Print "Next time analysis is run: Aligning on SomaByDiam."
	else
		AlignOnL4L5 = 1
		Print "Next time analysis is run: Aligning on L4/L5 boundary."
	endif
	
End

Function MakePVScatterGraph()

	NVAR	SourceIsHist

	// Scatter cluster
	Concatenate/O {Table_Type_1_37,Table_Type_2_37},PV_NMDARSupp
	// Manually add extra input onto the one morphology
	Duplicate/O PV_axonAreaAboveL5,PV_axonAreaAboveL5_2
	Duplicate/O PV_NMDARSupp,PV_NMDARSupp_2
	Duplicate/O PV_typeWave,PV_typeWave_2
	PV_axonAreaAboveL5_2[numpnts(PV_axonAreaAboveL5_2)] = {PV_axonAreaAboveL5_2[4]}
	PV_NMDARSupp_2[numpnts(PV_NMDARSupp_2)] = {60.15}
	PV_typeWave_2[numpnts(PV_typeWave_2)] = {PV_typeWave_2[0]}
	if (SourceIsHist)
		SetScale d 0,0,"mm", PV_axonAreaAboveL5_2
	else
		SetScale d 0,0,"µm^2", PV_axonAreaAboveL5_2
	endif
	SetScale d 0,0,"%", PV_NMDARSupp, PV_NMDARSupp_2
	
	Variable	n = numpnts(PV_typeWave_2)
	Make/O/N=(n,3) PV_colWave
	Make/O/N=(0) t1_xData,t1_yData,t2_xData,t2_yData
	Variable	i
	i = 0
	do
//	ModifyGraph rgb(Gaussian_Left)=(0,0,65280),rgb(Gaussian_Right)=(0,43520,65280)
		if (PV_typeWave_2[i]<0.5)
			PV_colWave[i][0]=0
			PV_colWave[i][1]=43520
			PV_colWave[i][2]=65280
			t1_xData[numpnts(t1_xData)] = {PV_axonAreaAboveL5_2[i]}
			t1_yData[numpnts(t1_yData)] = {PV_NMDARSupp_2[i]}
		else
			PV_colWave[i][0]=0
			PV_colWave[i][1]=0
			PV_colWave[i][2]=65280
			t2_xData[numpnts(t2_xData)] = {PV_axonAreaAboveL5_2[i]}
			t2_yData[numpnts(t2_yData)] = {PV_NMDARSupp_2[i]}
		endif
		i += 1
	while(i<n)

	DoWindow/K PV_ScatterGr
	Display /W=(35,44,430,252) PV_NMDARSupp_2 vs PV_axonAreaAboveL5_2
	nw("PV_ScatterGr")
	ModifyGraph mode(PV_NMDARSupp_2)=3
	ModifyGraph marker(PV_NMDARSupp_2)=19
	ModifyGraph rgb(PV_NMDARSupp_2)=(0,0,65535)
//	ModifyGraph fSize=14
	Label left "NMDAR supp (\\U)"
//	SetAxis/A/N=1 left
	SetAxis/A/N=1 left,40,110
//	SetAxis/A/N=2 bottom
	ModifyGraph zColor(PV_NMDARSupp_2)={PV_colWave,*,*,directRGB,0}
	ModifyGraph manTick(left)={100,50,0,0},manMinor(left)={4,50}

	if (SourceIsHist)
		Label bottom "Axon length (\\U)"
		SetAxis bottom -500,3000
//		ModifyGraph prescaleExp(bottom)=3
//		Label bottom "Axon hull area (\\u#2x10\\S4\\M µm\\S2\\M)"
		ModifyGraph manTick(bottom)={0,1000,0,0},manMinor(bottom)={1,50}
	else
		Label bottom "Axon hull area (\\U)"
		SetAxis bottom -15000,90000
		ModifyGraph prescaleExp(bottom)=2
		Label bottom "Axon hull area (\\u#2x10\\S4\\M µm\\S2\\M)"
		ModifyGraph manTick(bottom)={0,5,6,0},manMinor(bottom)={4,50}
	endif
	ModifyGraph fsize=10
	ModifyGraph msize=4
	
	// Make ovals
	Variable oval_x1,oval_x2
	Variable oval_y1,oval_y2
	Variable SD_scale = 2

	WaveStats/Q t1_xData
	oval_x1 = V_avg-V_sdev*SD_scale
	oval_x2 = V_avg+V_sdev*SD_scale
	WaveStats/Q t1_yData
	oval_y1 = V_avg-V_sdev*SD_scale
	oval_y2 = V_avg+V_sdev*SD_scale
	
	SetDrawLayer UserFront
	SetDrawEnv linefgc= (0,43520,65280),dash= 11,fillpat= 0,xcoord= bottom,ycoord= left
	DrawOval oval_x1,oval_y1,oval_x2,oval_y2

	WaveStats/Q t2_xData
	oval_x1 = V_avg-V_sdev*SD_scale
	oval_x2 = V_avg+V_sdev*SD_scale
	WaveStats/Q t2_yData
	oval_y1 = V_avg-V_sdev*SD_scale
	oval_y2 = V_avg+V_sdev*SD_scale
	
	SetDrawLayer UserFront
	SetDrawEnv linefgc= (0,0,65280),dash= 11,fillpat= 0,xcoord= bottom,ycoord= left
	DrawOval oval_x1,oval_y1,oval_x2,oval_y2
	
	PWBarsPV()	

End

////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Show all reconstructions of all types
////	Used this to construct the cover page suggestion for Txomin's JPhysiol 2015 paper

Function showAllRecons(nCols)
	Variable	nCols

	print "=== Showing all reconstructions ==="
	
	DoWindow/K AllRecons

	SVAR		typeList

	Variable	n = ItemsInList(typeList)
	String		ListOfAll = ""
	Print "Found "+num2str(n)+" types"
	String		currType
	Variable	i,j
	Variable	nEntries
	i = 0
	do
		currType = StringFromList(i,typeList)
		WAVE/T	currTable = $("Table_"+currType)
		nEntries = numpnts(currTable)
		Print "\tFound "+num2str(nEntries)+" entries in type \""+currType+"\"."
		j = 0
		do
			ListOfAll += currTable[j]+","+currType+";"
			j += 1
		while(j<nEntries)
		i += 1
	while(i<n)
	Variable	nAll = ItemsInList(ListOfAll)
	Print "Total number of reconstructions:",nAll

	Variable	xFactor = 0.4
	Variable	yFactor = 0.8
	NVAR		xMin
	NVAR		xMax
	NVAR		yMin
	NVAR		yMax
	Variable	xSpacing = abs(xMax-xMin)*xFactor
	Variable	ySpacing = abs(yMax-yMin)*yFactor
//	Variable	nRows = Ceil(nAll/nCols)
	Variable	nRows = Floor(nAll/nCols)

	Variable	AppendFlag = 1
	Variable	xOffset
	Variable	yOffset
	String		Suff
	String		currEntry
	String		thisReconName
	String		lastType = ""

	DoWindow/K ReconPlot
	Display as "Placeholder for reconstructions"
	DoWindow/C ReconPlot
	AppendToGraph yLimits vs xLimits
	ModifyGraph mode=2
	SetAxis left,yMin*0.6,yMax*0.0+(nRows-1)*ySpacing
	SetAxis bottom,xMin*0.25,xMax*xFactor+(nCols-1)*xSpacing
	DoUpdate

	i = 0
	j = 0
	do
		currEntry = StringFromList(i,ListOfAll)
		currType = StringFromList(1,currEntry,",")
		thisReconName = StringFromList(0,currEntry,",")
		thisReconName = thisReconName[1,StrLen(thisReconName)-1]
		if (!(StringMatch(LastType,currType)))
			j = 0
			lastType = currType
		endif
		Suff = "_"+currType+"_"+num2str(j+1)
		xOffset = MOD(i,nCols)*xSpacing
		yOffset = Floor(i/nCols)*ySpacing
		print MOD(i,nCols),Floor(i/nCols),currType,Suff,thisReconName
		ShowReconstruction(Suff,AppendFlag,xOffset,yOffset,thisReconName,0)
		j += 1
		i += 1
//	while(i<nAll)
	while(i<nAll-MOD(nAll,nCols))
	
	nw("AllRecons")
	JT_AddCloseButton()
	JT_ArrangeGraphs2("AllRecons;",1,2)
	ModifyGraph margin(left)=4,margin(bottom)=4
	RemoveAxes()
	ModifyGraph width={Plan,1,bottom,left}

End

Function SpreadReconsLaterally()

	Variable 	Keys = GetKeyState(0)
	NVAR		xMin
	NVAR		xMax
	
	Variable	xSpacing = abs(xMax-xMin)
	Variable	unspread = 0

	String		topGraphStr = StringFromList(0,WinList("*",";","WIN:1"))
	String		grNamePrefix = topGraphStr[0,9]
	String		grNameSuffix = topGraphStr[StrLen(topGraphStr)-1-4,StrLen(topGraphStr)-1]
	String		Condition = topGraphStr[10,StrLen(topGraphStr)-1-5]
	
	if ( (StringMatch("ReconPlot_",grNamePrefix)) %& (StringMatch("_KEEP",grNameSuffix)))			// Is top graph a reconstruction plot graph?
	
		Print "Spreading the reconstructions in top graph "+topGraphStr
		DoWindow/K SpreadRecons

		print "\tThe condition in the top graph is:",Condition
		
		WAVE/T	reconNames = $("Table_"+Condition)
		
		Variable	n = numpnts(reconNames)
		
		print "\tThere are "+num2str(n)+" reconstructions in this graph"
		
		Variable	AppendFlag = 0
		Variable	xOffset
		String		Suff = ""
		String		thisReconName = ""
		Variable	i
		i = 0
		do
			if (i==0)
				AppendFlag = 0
			else
				AppendFlag = 1
			endif
			Suff = "_"+Condition+"_"+num2str(i+1)
			xOffset = i*xSpacing
			thisReconName = reconNames[i]
			thisReconName = thisReconName[1,StrLen(thisReconName)-1]
			ShowReconstruction(Suff,AppendFlag,xOffset,0,thisReconName,1)
			i += 1
		while(i<n)
		
		nw("SpreadRecons")
		JT_AddCloseButton()
		JT_ArrangeGraphs2("SpreadRecons;",3,2)
		ModifyGraph margin(left)=40
		
	else
	
		Print "Top graph does not have any reconstructions in it."

	endif

End

Function MakeBackGroundBlackPV()

	SVAR		typeList
	String/G	SaveTypeList = typeList
	typeList = "PV;"
	MakeBackGroundBlack()
	typeList = SaveTypeList

End

Function MakeBackGroundBlack()

	SVAR		typeList
	
	SVAR		LA_whichVar
	
	Variable	n = ItemsInList(typeList)
	Variable	i,j,nTraces
	String		currType,ListOfTraces,currTrace1,currTrace2
	Variable	colDiv = 3
	i = 0
	do
		currType = StringFromList(i,typeList)
//		print currType
		// Reconstructions
		DoWindow/F $("ReconPlot_"+currType+"_KEEP")
		ModifyGraph wbRGB=(0,0,0),gbRGB=(0,0,0)
		ModifyGraph opaque=0
		ModifyGraph axRGB=(65535,65535,65278)
		ModifyGraph tlblRGB=(65535,65535,65278)
		ModifyGraph alblRGB=(65535,65535,65278)
		Legend/K/N=text0
		ModifyGraph noLabel(bottom)=1
		// All traces
		ListOfTraces = TraceNameList("",";",1)
		nTraces = ItemsInList(ListOfTraces)/3
		j = 0
		do
			currTrace1 = "drawY_"+currType+"_"+num2str(j+1)
			currTrace2 = "drawCT_"+currType+"_"+num2str(j+1)
			print "\t"+currTrace1,currTrace2
//			ModifyGraph zColor($(currTrace1))={$(currTrace2),2,*,CyanMagenta,0}
			ModifyGraph/Z zColor($(currTrace1))={$(currTrace2),*,*,cindexRGB,0,myColors}
			j += 1
		while(j<nTraces)
		// Flux maps
		DoWindow/F $("Map2_"+currType)
		ModifyGraph wbRGB=(0,0,0),gbRGB=(0,0,0)
//		ModifyGraph opaque=0
		ModifyGraph axRGB=(65535,65535,65278)
		ModifyGraph tlblRGB=(65535,65535,65278)
		ModifyGraph alblRGB=(65535,65535,65278)
		Legend/K/N=text0
		ModifyGraph noLabel(bottom)=0
		// Sholl graphs
		DoWindow/F $("Sholl_"+currType)
		ModifyGraph wbRGB=(0,0,0),gbRGB=(0,0,0)
		ModifyGraph opaque=0
		ModifyGraph axRGB=(65535,65535,65278)
		ModifyGraph tlblRGB=(65535,65535,65278)
		ModifyGraph alblRGB=(65535,65535,65278)
			ModifyGraph mode($("DendrShollYposSEM_"+currType))=7
			ModifyGraph mode($("DendrShollYnegSEM_"+currType))=7
			ModifyGraph lSize($("DendrShollYposSEM_"+currType))=0
			ModifyGraph lSize($("DendrShollYnegSEM_"+currType))=0
			ModifyGraph rgb($("DendrShollYposSEM_"+currType))=(65535/colDiv,0,65535/colDiv)
			ModifyGraph hbFill($("DendrShollYposSEM_"+currType))=2
			ModifyGraph toMode($("DendrShollYposSEM_"+currType))=1
			ModifyGraph mode($("AxonShollYposSEM_"+currType))=7
			ModifyGraph mode($("AxonShollYnegSEM_"+currType))=7
			ModifyGraph lSize($("AxonShollYposSEM_"+currType))=0
			ModifyGraph lSize($("AxonShollYnegSEM_"+currType))=0
			ModifyGraph rgb($("AxonShollYposSEM_"+currType))=(65535/colDiv,65535/colDiv,0)
			ModifyGraph hbFill($("AxonShollYposSEM_"+currType))=2
			ModifyGraph toMode($("AxonShollYposSEM_"+currType))=1
		Legend/K/N=text0
		// Layer analysis graphs
		DoWindow/F $("LayerAnGr_"+currType)
		ModifyGraph wbRGB=(0,0,0),gbRGB=(0,0,0)
		ModifyGraph opaque=0
		ModifyGraph axRGB=(65535,65535,65278)
		ModifyGraph tlblRGB=(65535,65535,65278)
		ModifyGraph alblRGB=(65535,65535,65278)
		ModifyGraph rgb($("mLayAxonHist_"+LA_whichVar+"_"+currType))=(65535,50000,3600)
		ModifyGraph rgb($("mLayDendrHist_"+LA_whichVar+"_"+currType))=(65535,0,65535)
		Legend/K/N=text0
//		ModifyGraph prescaleExp(left)=-3
		modifygraph fsize=8
		ModifyGraph tlOffset(bottom)=2
		ModifyGraph hbFill=2
//		SetAxis/A/N=1 left
//		SetAxis left 0,5000
		i += 1
	while(i<n)
	
End

Function MakeBackGroundWhite()

	SVAR		typeList

	SVAR		LA_whichVar
	
	Variable	n = ItemsInList(typeList)
	Variable	i,j,nTraces
	String		currType,ListOfTraces,currTrace1,currTrace2
	Variable	colMul = 0.8
	Variable	gbGray = 50000
	i = 0
	do
		currType = StringFromList(i,typeList)
//		print currType
		// Reconstructions
		DoWindow/F $("ReconPlot_"+currType+"_KEEP")
		ModifyGraph wbRGB=(65535,65535,65535)//,gbRGB=(65535,65535,65535)
		ModifyGraph gbRGB=(gbGray,gbGray,gbGray)
		ModifyGraph opaque=0
		ModifyGraph axRGB=(0,0,0)
		ModifyGraph tlblRGB=(0,0,0)
		ModifyGraph alblRGB=(0,0,0)
		Legend/K/N=text0
		ModifyGraph noLabel(bottom)=1
		ModifyGraph noLabel(left)=1
		// All traces
		ListOfTraces = TraceNameList("",";",1)
		nTraces = ItemsInList(ListOfTraces)/3
		j = 0
		do
			currTrace1 = "drawY_"+currType+"_"+num2str(j+1)
			currTrace2 = "drawCT_"+currType+"_"+num2str(j+1)
			print "\t"+currTrace1,currTrace2
//			ModifyGraph zColor($(currTrace1))={$(currTrace2),2,*,CyanMagenta,0}
			ModifyGraph/Z zColor($(currTrace1))={$(currTrace2),*,*,cindexRGB,0,myColors}
			ModifyGraph/Z hideTrace($("yCoord2LF_"+currType+"_"+num2str(j+1)))=1
			j += 1
		while(j<nTraces)
		SetDrawLayer UserFront
		SetDrawEnv linefgc= (65535/2,65535/2,65535/2)
		SetDrawEnv xcoord= prel,ycoord= left,dash= 1
		DrawLine 0,0,1,0
		AddLayerBoundaries(currType,0)
		// Flux maps
		DoWindow/F $("Map2_"+currType)
		ModifyGraph wbRGB=(65535,65535,65535),gbRGB=(65535,65535,65535)
//		ModifyGraph opaque=0
		ModifyGraph axRGB=(0,0,0)
		ModifyGraph tlblRGB=(0,0,0)
		ModifyGraph alblRGB=(0,0,0)
		Legend/K/N=text0
		ModifyGraph noLabel(bottom)=0
		// Sholl graphs
		DoWindow/F $("Sholl_"+currType)
		ModifyGraph wbRGB=(65535,65535,65535),gbRGB=(65535,65535,65535)
		ModifyGraph opaque=0
		ModifyGraph axRGB=(0,0,0)
		ModifyGraph tlblRGB=(0,0,0)
		ModifyGraph alblRGB=(0,0,0)
			ModifyGraph mode($("DendrShollYposSEM_"+currType))=7
			ModifyGraph mode($("DendrShollYnegSEM_"+currType))=7
			ModifyGraph lSize($("DendrShollYposSEM_"+currType))=0
			ModifyGraph lSize($("DendrShollYnegSEM_"+currType))=0
			ModifyGraph rgb($("DendrShollYposSEM_"+currType))=(65535,65535*colMul,65535)
			ModifyGraph hbFill($("DendrShollYposSEM_"+currType))=2
			ModifyGraph toMode($("DendrShollYposSEM_"+currType))=1
			ModifyGraph mode($("AxonShollYposSEM_"+currType))=7
			ModifyGraph mode($("AxonShollYnegSEM_"+currType))=7
			ModifyGraph lSize($("AxonShollYposSEM_"+currType))=0
			ModifyGraph lSize($("AxonShollYnegSEM_"+currType))=0
			ModifyGraph rgb($("AxonShollYposSEM_"+currType))=(65535,65535,65535*colMul*0.5)
			ModifyGraph hbFill($("AxonShollYposSEM_"+currType))=2
			ModifyGraph toMode($("AxonShollYposSEM_"+currType))=1
		Legend/K/N=text0
		SetAxis/A/E=1 left
		ModifyGraph nticks(left)=2
		// Layer analysis graphs
		DoWindow/F $("LayerAnGr_"+currType)
		ModifyGraph wbRGB=(65535,65535,65535),gbRGB=(65535,65535,65535)
		ModifyGraph opaque=0
		ModifyGraph axRGB=(0,0,0)
		ModifyGraph tlblRGB=(0,0,0)
		ModifyGraph alblRGB=(0,0,0)
		ModifyGraph rgb($("mLayAxonHist_"+LA_whichVar+"_"+currType))=(65535,50000,3600)
		ModifyGraph rgb($("mLayDendrHist_"+LA_whichVar+"_"+currType))=(65535,0,65535)
		Legend/K/N=text0
		ModifyGraph prescaleExp(left)=-3
		modifygraph fsize=8
		ModifyGraph tlOffset(bottom)=2
		ModifyGraph hbFill=2
		i += 1
	while(i<n)
	
End

Function ReloadAll()

	Print "=== Reload everything ==="
	
	DoAlert 1,"This will take a while? Are you sure?"
	if (V_flag!=1)
		Return -1
	endif
	
	Variable	timerRef = startMSTimer
	
//	Variable	startTicks = ticks

	CreateGlobalVars()
	SVAR		typeList
	Variable	n = ItemsInList(typeList)
	Variable	i
	String		currType
	PathInfo	home
	String		homeFolderStr = S_path
	i = 0
	do
		currType = StringFromList(i,typeList)
		LoadReconFolder(homeFolderStr+currType)
		i += 1
	while(i<n)
	
	ReBlend()
	FixAspectRatioAllGraphs()
	
	Variable	microSeconds = stopMSTimer(timerRef)
	Variable	minutes = Floor(microSeconds/1e6/60)
	Variable	seconds = microSeconds/1e6-minutes*60
	print "This took "+num2str(minutes)+" minutes and "+num2str(seconds)+" seconds"

End

Function CreateGlobalVars()

	String/G	MapGraphList = ""

	Make/O/N=(6,3) myColors
	myColors = nan
	myColors[0][0]= {65535,65535,65535,65535,65535,65535}
	myColors[0][1]= {65535,65535,65535,0,0,0}
	myColors[0][2]= {0,0,0,65535,65535,65535}

End

Function GraphsToFront()

	SVAR		MapGraphList
	JT_ArrangeGraphs3(MapGraphList)
	
End

Function FixAspectRatioAllGraphs()

	SVAR		MapGraphList

	Variable	n = ItemsInList(MapGraphList)
	String		currGraph
	Variable	i
	i = 0
	do
		currGraph = StringFromList(i,MapGraphList)
		if ( (!(StringMatch(currGraph[0,4],"Sholl"))) %& (!(StringMatch(currGraph[0,8],"LayerAnGr"))) )
			ModifyGraph/W=$(currGraph) width={Plan,1,bottom,left}
		endif
		i += 1
	while(i<n)

End


Function ReBlend()

//	Print "=== Reblending maps ==="

	CreateGlobalVars()
	SVAR		typeList
	SVAR		MapGraphList
	NVAR	AlignOnL4L5
	MapGraphList = ""
	Variable	n = ItemsInList(typeList)
	Variable	i
	String		currType
	i = 0
	do
		currType = StringFromList(i,typeList)
		doBlend("_"+currType,2,0.8)
		if (AlignOnL4L5)
			AddLayerBoundaries(currType,1)
		endif
		doBlend("2_"+currType,2,1)
		if (AlignOnL4L5)
			AddLayerBoundaries(currType,1)
		endif
		MapGraphList += "Map_"+currType+";"
		MapGraphList += "Map2_"+currType+";"
		MapGraphList += "ReconPlot_"+currType+"_KEEP;"
		MapGraphList += "Sholl_"+currType+";"
		MapGraphList += "LayerAnGr_"+currType+";"
//		SetAxis/W=$("Sholl_"+currType) left,0,50
		i += 1
	while(i<n)
	JT_ArrangeGraphs2(MapGraphList,5,8)
	
	Variable	MaxMax = 0
	i = 0
	do
		GetAxis/Q/W=$("Sholl_"+currType) left
		if (MaxMax<V_max)
			MaxMax = V_max
		endif
		i += 1
	while(i<n)
	i = 0
	do
		SetAxis/W=$("Sholl_"+currType) left,0,MaxMax
		i += 1
	while(i<n)	

End

Function doBlend(suff,colorMode,colorScaling)
	String		suff
	Variable	colorMode
	Variable	colorScaling

	WAVE		AxonMatrix = $("AxonMatrix"+suff)
	WAVE		DendrMatrix = $("DendrMatrix"+suff)

	BlendImage(AxonMatrix,DendrMatrix,colorMode,colorScaling)
	Duplicate/O MatrixRGB,$("MatrixRGB"+suff)

	DoWindow/K $("Map"+suff)
	NewImage/F  $("MatrixRGB"+suff)
 	nw("Map"+suff)
	ModifyGraph mirror=2
	SetDrawLayer UserFront
	SetDrawEnv linefgc= (65535/2,65535/2,65535/2)
	SetDrawEnv xcoord= prel,ycoord= left,dash= 1
	DrawLine 0,0,1,0

	ModifyGraph tick=1
	ModifyGraph manTick={0,200,0,0},manMinor={0,50}
	ModifyGraph margin(left)=24,margin(right)=8
	
	if (StringMatch(suff[0],"2"))
		if (Exists("qM_noAxon")==0)
			Variable/G qM_noAxon = 0
		endif
		NVAR qM_noAxon
		if (qM_noAxon==0)
			AppendToGraph $("AxonHoH_Y_"+suff[2,Inf]) vs $("AxonHoH_X_"+suff[2,Inf])
		endif
		AppendToGraph $("DendrHoH_Y_"+suff[2,Inf]) vs $("DendrHoH_X_"+suff[2,Inf])
		ModifyGraph lstyle=1
		if (qM_noAxon==0)
			ModifyGraph rgb($("AxonHoH_Y_"+suff[2,Inf]))=(65535,65535,0)		//(65535,65535,65535)
		endif
		ModifyGraph rgb($("DendrHoH_Y_"+suff[2,Inf]))=(65535,0,65535)
	endif

	TextBox/C/N=text0/J/F=0/B=1/G=(56797,56797,56797)/X=0.00/Y=0.00 "\\f01"+suff[strsearch(suff,"_",0)+1,Inf]
	JT_AddResizeButton()

End

Function BlendImage(axonMap,dendrMap,colorMode,colorScaling)
	WAVE		axonMap
	WAVE		dendrMap
	Variable	colorMode
	Variable	colorScaling

	// [r,g,b]
	
	Variable	nPointsColorRamp = 1000
	make/O/N=(nPointsColorRamp) colorRamp
	
	Variable	upScaleRed = 0.2
	Variable	upScaleBlue = 0.5

	Switch(colorMode)
		Case 1:
			colorRamp = p^0.35							// gamma correction
			WaveStats/Q colorRamp
			colorRamp /= V_max
			SetScale/I x 0,1,"", colorRamp

			ColorTab2Wave 'Red'
//			ColorTab2Wave 'Blue'
			Duplicate/O M_colors,GreenColors
			GreenColors[*][1] = GreenColors[p][0]*upScaleRed
			GreenColors[*][2] = GreenColors[p][0]*upScaleRed
//			GreenColors[*][2]*=colorScaling
			GreenColors[*][0]*=colorScaling
			GreenColors[*][1]*=colorScaling
			GreenColors[*][2]*=colorScaling
			ColorTab2Wave 'Blue'
//			ColorTab2Wave 'Red'
			Duplicate/O M_colors,BlueColors
			BlueColors[*][0] = BlueColors[p][2]*upScaleBlue
			BlueColors[*][1] = BlueColors[p][2]*upScaleBlue
//			BlueColors[*][1]*=colorScaling
			BlueColors[*][0]*=colorScaling
			BlueColors[*][1]*=colorScaling
			BlueColors[*][2]*=colorScaling
			GreenColors *= colorRamp(GreenColors[p][0]/65535)/(GreenColors[p][0]/65535)
			BlueColors *= colorRamp(BlueColors[p][2]/65535)/(BlueColors[p][2]/65535)
			Break
		Case 2:
			colorRamp = p^0.5							// gamma correction
			WaveStats/Q colorRamp
			colorRamp /= V_max
			SetScale/I x 0,1,"", colorRamp
			ColorTab2Wave 'Yellow'
//			ColorTab2Wave 'Cyan'
			Duplicate/O M_colors,GreenColors
			GreenColors[*][0]*=colorScaling
			GreenColors[*][1]*=colorScaling
			GreenColors[*][2]*=colorScaling
			ColorTab2Wave 'Magenta'
//			ColorTab2Wave 'Magenta'
			Duplicate/O M_colors,BlueColors
			BlueColors[*][0]*=colorScaling
			BlueColors[*][1]*=colorScaling
			BlueColors[*][2]*=colorScaling
			GreenColors *= colorRamp(GreenColors[p]/65535)/(GreenColors[p]/65535)
			BlueColors *= colorRamp(BlueColors[p]/65535)/(BlueColors[p]/65535)
			Break
		Default:
			Print "Strange error in {BlendImage}"
			Abort "Strange error in {BlendImage}"
	endSwitch
	
//	DoWindow/F gamma_correction
	
	
	Variable	percentSaturated = 5

	Duplicate/O axonMap,axonMap_Norm
	ImageStats/Q axonMap_Norm
	axonMap_Norm *= 2^8/(V_max*(100-percentSaturated)/100)
	ImageTransform/C=GreenColors cmap2rgb axonMap_Norm
	Duplicate/O M_RGBOut,axonMap_Norm_RGB

	Duplicate/O DendrMap,DendrMap_Norm
	ImageStats/Q DendrMap_Norm
	DendrMap_Norm *= 2^8/(V_max*(100-percentSaturated)/100)
	ImageTransform/C=BlueColors cmap2rgb DendrMap_Norm
	Duplicate/O M_RGBOut,DendrMap_Norm_RGB

	Duplicate/O DendrMap_Norm_RGB,MatrixRGB
	if (Exists("qM_noAxon")==0)
		Variable/G qM_noAxon = 0
	endif
	NVAR qM_noAxon
	if (qM_noAxon)
		MatrixRGB = DendrMap_Norm_RGB
	else
		MatrixRGB = (axonMap_Norm_RGB %| DendrMap_Norm_RGB)
	endif

	NVAR	xMin
	NVAR	xMax
	NVAR	yMin
	NVAR	yMax
	NVAR	StepSize
	
	Variable	xN = (xMax-xMin)/StepSize+1
	Variable	yN = (yMax-yMin)/StepSize+1
	
	SetScale/P x,xMin,StepSize,MatrixRGB
	SetScale/P y,yMin,StepSize,MatrixRGB

End

Function Make_Recon_Panel()

	String		FuncNames,Titles
	
	FuncNames = ""
	Titles = ""
	
	FuncNames += "ReloadAll;"
	Titles += "Reload all;"

	FuncNames += "LoadReconFolder2;"
	Titles += "Load recon folder;"

	FuncNames += "LoadRecon;"
	Titles += "Load single recon;"

	FuncNames += "ReconStats;"
	Titles += "Show recon stats [4 types];"

	FuncNames += "ReconStats2;"
	Titles += "Show recon stats [3 types];"

	FuncNames += "RotTableToFront;"
	Titles += "Rotation table to front;"

	FuncNames += "LayerMapTableToFront;"
	Titles += "Layer mapping table to front;"

	FuncNames += "ReBlend;"
	Titles += "Reblend matrix maps;"
	
	FuncNames += "FixAspectRatioAllGraphs;"
	Titles += "Fix aspect ratio for all graphs;"

	FuncNames += "GraphsToFront;"
	Titles += "Graphs to front;"
	
	FuncNames += "MakeBackGroundBlack;"
	Titles += "Make background black;"

//	FuncNames += "MakeBackGroundBlackPV;"
//	Titles += "Make backgnd black for PV;"

	FuncNames += "MakeBackGroundWhite;"
	Titles += "Make background white;"

	FuncNames += "SpreadReconsLaterally;"
	Titles += "Spread recons laterally;"

	FuncNames += "ToggleAlignOnL4L5;"
	Titles += "Align on soma or L4/L5?;"

	FuncNames += "Make_Recon_Panel;"
	Titles += "Redraw this panel;"

	JT_MakePanel("Recon_Panel","Recon Tools",FuncNames,Titles)

End

Function RotTableToFront()

	DoWindow/F Rotation_table

End

Function LayerMapTableToFront()

	DoWindow/F LayerMappingTable

End

Function RotateRecon(rotAngle,Suff)
	Variable	rotAngle
	String		Suff

	DoTheRotate(rotAngle,"yCoord2"+Suff,"xCoord2"+Suff)

End

// Rotate coordinates counter clockwise about the origin for the two given axes

Function DoTheRotate(rotAngle,yName,xName)
	Variable	rotAngle
	String		yName
	String		xName
	
	WAVE		xWave = $(xName)
	WAVE		yWave = $(yName)

	Variable	radAngle = rotAngle*pi/180
	Variable	nPoints = numpnts(xWave)

	Make/O/N=(nPoints,2) xxyy,xxyy2
	xxyy[0,nPoints-1][0] = xWave[p]
	xxyy[0,nPoints-1][1] = yWave[p]
	
	Make/O/N=(2,2) rotMat
	
	rotMat[0][0] = cos(radAngle)
	rotMat[0][1] = -sin(radAngle)
	rotMat[1][0] = sin(radAngle)
	rotMat[1][1] = cos(radAngle)
	
	MatrixOP/O xxyy2 = rotMat x xxyy^t
	
	xWave[0,nPoints-1] =xxyy2[0][p]
	yWave[0,nPoints-1] =xxyy2[1][p]

End

Function moreRotate()

	Variable	n = 100
	Variable	i
	
	variable	NowTick
	i = 0
	do
		nowTick = ticks
		do
		while(nowTick+10>ticks)
		testRotate(0)
		DoUpdate
		i += 1
	while(i<n)

end

Function testRotate(doReset)
	Variable	doReset

	Variable	n = 100

	Make/O/N=(2) theseCoords,rotCoords
	Make/O/N=(n) xx,yy
	if (doReset)
		yy = gnoise(4)
		xx = gnoise(4)+x
		xx -= n/2
	endif
	
	Make/O/N=(n,2) xxyy,xxyy2
	xxyy[0,n-1][0] = xx[p]
	xxyy[0,n-1][1] = yy[p]
	
	Variable	rotAngle = -10
	Variable	radAngle = rotAngle*pi/180
	
	Make/O/N=(2,2) rotMat
	
	rotMat[0][0] = cos(radAngle)
	rotMat[0][1] = -sin(radAngle)
	rotMat[1][0] = sin(radAngle)
	rotMat[1][1] = cos(radAngle)
	
	MatrixOP/O xxyy2 = rotMat x xxyy^t
	
	xx[0,n-1] =xxyy2[0][p]
	yy[0,n-1] =xxyy2[1][p]

End

Function ReconStatsFor(theStr)
	String		theStr

	Variable	index = FindVarStr(theStr)
	
	if (index==-1)
		print "Could not find that string!"
	else
		ReconStatistics(index)
	endif

End

Function ReconStatistics(which)
	Variable	which

	SVAR	typeList

	Variable	n = ItemsInList(typeList)
	Variable	i,j
	if (n>1)
		i = 0
		do
			j = i+1
			do
//				print i,j,StringFromList(i,typeList),StringFromList(j,typeList)
				DoReconStats(StringFromList(i,typeList),StringFromList(j,typeList),which)
				j += 1
			while(j<n)
			i += 1
		while(i<n-1)
	else
		if (n==1)
			DoReconStats(StringFromList(0,typeList),StringFromList(0,typeList),which)
		else
			Print "n = 0 -- no stored data!"
		endif
	endif

End

Function ReconStats()

	DoReconStats("Type_1","Type_2",-1)
	DoReconStats("Type_1","SOM",-1)
	DoReconStats("SOM","Type_2",-1)

	Print "\r///////// Stats vs PC follows below /////////"
	DoReconStats("Type_1","PC",-1)
	DoReconStats("Type_2","PC",-1)
	DoReconStats("SOM","PC",-1)

End

Function ReconStats2()

	Print "\r///////// Stats for all PV vs SOM and vs PC follows below /////////"
	DoReconStats("PV","PC",-1)
	DoReconStats("PV","SOM",-1)
	DoReconStats("SOM","PC",-1)

End

Function PWBarsPV()

//	String	ColStr = "26;27;28;29;"
	String	ColStr = "28;29;"
	NVAR	SourceIsHist
	if (SourceIsHist)
		ColStr = "42;43;"
	endif

	PairwiseBars("Type_1","Type_2",ColStr)
	if (SourceIsHist)
		ModifyGraph/W=PairwiseGr42 rgb=(65535,50000,3600)
		Legend/W=PairwiseGr42/K/N=text0
		ModifyGraph/W=PairwiseGr43 rgb=(65535,0,65535)
		Legend/W=PairwiseGr43/K/N=text0
		ModifyGraph/W=PairwiseGr42 nticks(left)=3
		ModifyGraph/W=PairwiseGr43 nticks(left)=3
		ModifyGraph/W=PairwiseGr42 prescaleExp(left)=-3,manTick(left)={0,1,0,0},manMinor(left)={1,50}
		Label/W=PairwiseGr42 left "\\u#2axon length (mm)"
		ModifyGraph/W=PairwiseGr43 prescaleExp(left)=-3,manTick(left)={0,1,0,0},manMinor(left)={1,50}
		Label/W=PairwiseGr43 left "\\u#2axon length (mm)"
		WAVE/T PairwiseXlabel
		PairwiseXlabel[0] = "type 1"
		PairwiseXlabel[1] = "type 2"
	endif
	DoUpdate
	CopyAxesRanges()

End

Function PairwiseBars(type1,type2,colList)
	String	type1,type2,colList
	
	Variable	n = ItemsInList(colList)
	SVAR		VarStr
	String		currVar
	Variable	i,j,pVal
	String/G	PairwiseGrList = ""
	Make/O/T/N=(2) PairwiseXlabel = {type1,type2}
	i = 0
	do
		j = Str2Num(StringFromList(i,colList))
		WAVE	tableWave1 = $("Table_"+type1+"_"+num2str(j+1))
		WAVE	tableWave2 = $("Table_"+type2+"_"+num2str(j+1))
		Make/O/N=(2) $("PairwiseY"+num2str(j)),$("PairwiseSEM"+num2str(j))
		WAVE	wY = $("PairwiseY"+num2str(j))
		WAVE	wSEM = $("PairwiseSEM"+num2str(j))
		WaveStats/Q tableWave1
		wY[0] = V_avg
		wSEM[0] = V_sdev/sqrt(V_npnts)
		WaveStats/Q tableWave2
		wY[1] = V_avg
		wSEM[1] = V_sdev/sqrt(V_npnts)
		pVal = CorrectedStatTTest(tableWave1,tableWave2)
		print StringFromList(i,colList)+" -- p value for "+type1+" versus "+type2+":",pVal
		JT_BarGraph(NameOfWave(wY),"PairwiseXlabel","",NameOfWave(wSEM),"PairwiseGr"+num2str(j))
		if (pVal<0.05)
			JT_3BarsSigStars("PairwiseGr"+num2str(j),"*","","")
		endif
		if (pVal<0.001)
			JT_3BarsSigStars("PairwiseGr"+num2str(j),"**","","")
		endif
		if (pVal<0.0001)
			JT_3BarsSigStars("PairwiseGr"+num2str(j),"***","","")
		endif
		PairwiseGrList += "PairwiseGr"+num2str(j)+";"
		currVar = StringFromList(j,VarStr)
		Legend/C/N=text0/J/F=0/B=1/A=MT/X=0.00/Y=0.00/E=2 currVar
		i += 1
	while(i<n)
	
	JT_ArrangeGraphs2(PairwiseGrList,4,6)
	
End

Function FindVarStr(theStr)
	String		theStr
	
	SVAR		VarStr
	
	Variable	index = -1

	Variable	n = ItemsInList(VarStr)
	Variable	i
	do
		if (StringMatch(StringFromList(i,VarStr),theStr))
			Print "Match for "+num2str(i)+": "+StringFromList(i,VarStr)
			index = i
			i = Inf
		endif
		i += 1
	while (i<n)
	
	Return index

End

Function DoReconStats(type1,type2,which)
	String		type1,type2
	Variable	which
	
	SVAR		VarStr
	
	Print "\r================== DOING STATS =================="
	Print "Comparing types \""+Type1+"\" and \""+Type2+"\"."

	SVAR		ReconList1 = $("ReconList_"+Type1)
	Print "ReconList 1:",ReconList1
	SVAR		ReconList2 = $("ReconList_"+Type2)
	Print "ReconList 2:",ReconList2

	Variable	noMatch = 0	
	if (StringMatch(type1,type2))
		noMatch = 1
	endif

	Variable	n = ItemsInList(VarStr)
	Variable	i
	String		currVar
	Variable	pVal,pVal2
	if (which==-1)
		i = 0
	else
		i = which
	endif
	do
		currVar = StringFromList(i,VarStr)
		if (noMatch)
			WAVE	tableWave1 = $("Table_"+type1+"_"+num2str(i+1))
			WaveStats/Q tableWave1
			print JT_num2digstr(2,i)+" ======== "+currVar+" ========\tMean 1 =",V_avg,"±",V_sdev/sqrt(V_npnts),", n = ",V_npnts
		else
			WAVE	tableWave1 = $("Table_"+type1+"_"+num2str(i+1))
			WAVE	tableWave2 = $("Table_"+type2+"_"+num2str(i+1))
			pVal = CorrectedStatTTest(tableWave1,tableWave2)
			if ((numpnts(tableWave1)>10) %| (numpnts(tableWave2)>10))
				StatsWilcoxonRankTest/APRX=2/Q/TAIL=4 tableWave1,tableWave2		// Use approximation for large data sets
			else
				StatsWilcoxonRankTest/Q/TAIL=4 tableWave1,tableWave2
			endif
			WAVE	W_WilcoxonTest
			pVal2 = W_WilcoxonTest[5]
			if (pVal<0.05)
				print JT_num2digstr(2,i)+" ======== "+currVar+" ======== *** SIGNIFICANT ***  p(t-test) = "+num2str(pVal)+", p(WMW)="+num2str(pVal2)
			else
				print JT_num2digstr(2,i)+" ======== "+currVar+" ========  p = "+num2str(pVal)+", p(WMW)="+num2str(pVal2)
			endif
			WaveStats/Q tableWave1
			Print "Mean 1 =",V_avg,"±",V_sdev/sqrt(V_npnts),", n = ",V_npnts
			WaveStats/Q tableWave2
			Print "Mean 2 =",V_avg,"±",V_sdev/sqrt(V_npnts),", n = ",V_npnts
		endif
		if (which==-1)
			i += 1
		else
			i += Inf
		endif
	while(i<n)

End // StatsTtest

Function LoadReconFolder2()

	LoadReconFolder("")

End

Function LoadReconFolder(WhichFolder)
	String		WhichFolder
	
	String/G	fName
	String/G	pathName
	String/G	typeName

	if (StrLen(WhichFolder)==0)
		PathInfo ReconFolderPath
		if (V_flag)
			PathInfo/S ReconFolderPath												// Default to this path if it already exists
		endif
		NewPath/O/Q/M="Select folder with reconstructions!" ReconFolderPath
	else
		NewPath/O/Q ReconFolderPath,WhichFolder
	endif

	PathInfo ReconFolderPath
	if (V_flag)
		print "\tThe path to reconstructions is \""+S_path+"\""
	else
		print "ERROR! Path doesn't appear to exist!"
		Abort "ERROR! Path doesn't appear to exist!"
	endif
	typeName = JT_ScoreSpaceKillComma(StringFromList(ItemsInList(S_path,":")-1,S_path,":"))
	print		"\t\tType:",typeName
	
	String		fList = IndexedFile(ReconFolderPath,-1,".swc")
	Variable	nFiles = ItemsInList(fList)
	String/G	ReconList = ""
	print	"\tFound ",nFiles," reconstructions."

	Variable	i,j,k
	
	// Put data in table
	Variable	n = 4*6+6+2+4+1+3+2+2+2+2+4+2
	DoWindow/K $("theTable_"+typeName)
	Edit as "Data for "+typeName
	DoWindow/C $("theTable_"+typeName)
	Make/O/T/N=(nFiles) $("Table_"+typeName)
	WAVE/T	tableWaveTxt = $("Table_"+typeName)
	tableWaveTxt = ""
	AppendToTable/W=$("theTable_"+typeName) $("Table_"+typeName)
	i = 0
	do
		Make/O/N=(nFiles) $("Table_"+typeName+"_"+num2str(i+1))
		WAVE		tableWave = $("Table_"+typeName+"_"+num2str(i+1))
		tableWave = NaN
		AppendToTable/W=$("theTable_"+typeName) $("Table_"+typeName+"_"+num2str(i+1))
		i += 1
	while(i<n)

	// Load files
	Make/O/N=(0)		cAxonHoH_X,cAxonHoH_Y
	Make/O/N=(0)		cDendrHoH_X,cDendrHoH_Y
	CreateMatrices()
	Print "Loading files"
	String		currFile,currExp
	WAVE/T	tableWaveTxt = $("Table_"+typeName)
	i = 0
	do
		currFile = StringFromList(i,fList)
		ReconList += "w"+currFile[0,StrLen(currFile)-1-4]+";"
		tableWaveTxt[i] = "w"+currFile[0,StrLen(currFile)-1-4]
		LoadWave/Q/G/D/N/O/P=ReconFolderPath currFile
		fName = currFile
		print "File #"+num2str(i+1)+" out of "+num2str(nFiles)+" in total: \""+fName+"\" -- "+num2str((i+1)/nFiles*100)+"% done"
		pathName = S_path
		ConvertOnceLoaded("_"+typeName+"_"+num2str(i+1))
		AnalyzeRecon(typeName,i)
		// Collect Hull of Hull data
		Duplicate/O $("Axon_cHullX_"+typeName+"_"+num2str(i+1)),tempWave
		DeletePoints 0,1,tempWave
		Concatenate "tempWave;",cAxonHoH_X
		tempWave *= -1
		Concatenate "tempWave;",cAxonHoH_X
		Duplicate/O $("Axon_cHullY_"+typeName+"_"+num2str(i+1)),tempWave
		DeletePoints 0,1,tempWave
		Concatenate "tempWave;",cAxonHoH_Y
		tempWave -= 1e-3	// to avoid bug in FindConvexHull
		Concatenate "tempWave;",cAxonHoH_Y
		Duplicate/O $("Dendr_cHullX_"+typeName+"_"+num2str(i+1)),tempWave
		DeletePoints 0,1,tempWave
		Concatenate "tempWave;",cDendrHoH_X
		tempWave *= -1
		Concatenate "tempWave;",cDendrHoH_X
		Duplicate/O $("Dendr_cHullY_"+typeName+"_"+num2str(i+1)),tempWave
		DeletePoints 0,1,tempWave
		Concatenate "tempWave;",cDendrHoH_Y
		tempWave -= 1e-3	// to avoid bug in FindConvexHull
		Concatenate "tempWave;",cDendrHoH_Y
		delayUpdate
//		DoUpdate
		i += 1
	while(i<nFiles)

	WAVE LayDendrHist_Size_Casp6_WT_1

	// Compile layer analysis graphs
	CompileLayerAnalysis(typeName,nFiles)
	
	// Modify Sholl Analysis plot
	DoWindow/K $("Sholl_"+typeName)
	ModifyShollPlot(typeName)
	nw("Sholl "+typeName)
	JT_AddResizeButton()
	
	// Create Hull of Hulls
	FindConvexHull(cAxonHoH_X,cAxonHoH_Y)
	Duplicate/O cHullX,$("AxonHoH_X_"+typeName)
	Duplicate/O cHullY,$("AxonHoH_Y_"+typeName)
	FindConvexHull(cDendrHoH_X,cDendrHoH_Y)
	Duplicate/O cHullX,$("DendrHoH_X_"+typeName)
	Duplicate/O cHullY,$("DendrHoH_Y_"+typeName)
	
	// Figure out matrix images
//	Print "Copying matrices to "+"AxonMatrix_"+typeName+" and "+"DendrMatrix_"+typeName
	Duplicate/O AxonMatrix,$("AxonMatrix_"+typeName)
	Duplicate/O DendrMatrix,$("DendrMatrix_"+typeName)
	
//	Print "Copying smooth matrices to "+"AxonMatrix2_"+typeName+" and "+"DendrMatrix2_"+typeName
	Duplicate/O AxonMatrix2,$("AxonMatrix2_"+typeName)
	Duplicate/O DendrMatrix2,$("DendrMatrix2_"+typeName)
	
	print "ReconList",ReconList
	String/G	$("ReconList_"+typeName)
	SVAR		ReconListSave = $("ReconList_"+typeName)
	ReconListSave = ReconList

	DoWindow/K $("ReconPlot_"+typeName)
	DoWindow/K $("ReconPlot_"+typeName+"_KEEP")
	DoWindow/F ReconPlot
	JT_DuplicateGraph()
	DoWindow/K ReconPlot
	nw("ReconPlot_"+typeName)
	JT_AddResizeButton()

	JT_DuplicateGraph()
	nw("ReconPlot_"+typeName+"_KEEP")
	JT_AddResizeButton()
	String	WavesToRemove = ""
	WavesToRemove += WaveList("yCenters*",";","WIN:ReconPlot_"+typeName+"_KEEP")
	WavesToRemove += WaveList("Axon*",";","WIN:ReconPlot_"+typeName+"_KEEP")
	WavesToRemove += WaveList("Dendr*",";","WIN:ReconPlot_"+typeName+"_KEEP")
	i = 0
	n = ItemsInList(WavesToRemove)
	do
		RemoveFromGraph/Z/W=$("ReconPlot_"+typeName+"_KEEP") $(StringFromList(i,WavesToRemove))
		i += 1
	while(i<n)
	ModifyGraph mode=0,lsize=0.5
	Legend/C/N=text0/J/F=0/B=1 typeName
	NVAR	xMin,xMax,yMin,yMax
	SetAxis Bottom,xMin,xMax
	SetAxis Left,yMin,yMax
	ModifyGraph tkLblRot(left)=90
	
	doBlend("_"+typeName,2,0.8)
	NVAR	AlignOnL4L5
	if (AlignOnL4L5)
		AddLayerBoundaries(typeName,1)
	endif
	doBlend("2_"+typeName,2,1)
	if (AlignOnL4L5)
		AddLayerBoundaries(typeName,1)
	endif

End

Function CompileLayerAnalysis(typeName,nFiles)
	String		typeName
	Variable	nFiles
	
	// Although all three are calculated, only one is plotted -- determine which
	String/G	LA_whichVar = ""
	String		LabelStr = ""
	if (1)
		LA_whichVar = "Size"
		LabelStr = "length (mm)"
	else
		LA_whichVar = "N"
		LabelStr = "# compartments"
	endif

	String		LayerWavesStr = ""
	LayerWavesStr += "LayAxonHist_Size;"
	LayerWavesStr += "LayAxonHist_N;"
	LayerWavesStr += "LayAxonHist_Bool;"
	LayerWavesStr += "LayDendrHist_Size;"
	LayerWavesStr += "LayDendrHist_N;"
	LayerWavesStr += "LayDendrHist_Bool;"
	String		currLayerWave
	String		Suff = ""
	Variable	i,j,k
	Make/O/N=(nFiles) workWave
	k = 0
	do
		WAVE LayDendrHist_Size_Casp6_WT_1
		currLayerWave = StringFromList(k,LayerWavesStr)
		Make/O/N=(5) $("m"+currLayerWave+"_"+typeName),$("s"+currLayerWave+"_"+typeName)
		WAVE	mLayerWave = $("m"+currLayerWave+"_"+typeName)
		WAVE	sLayerWave = $("s"+currLayerWave+"_"+typeName)
		j = 0
		do
			i = 0
			do
				Suff = "_"+typeName+"_"+num2str(i+1)
				WAVE	w = $(currLayerWave+Suff)
				workWave[i] = w[j]
				i += 1
			while(i<nFiles)
			WaveStats/Q workWave
			mLayerWave[j] = V_avg
			sLayerWave[j] = V_sdev/sqrt(V_npnts)
			j += 1
		while(j<5)
		k += 1
	while(k<ItemsInList(LayerWavesStr))

	DoWindow/K $("LayerAnGr_"+typeName)
	Display $("mLayAxonHist_"+LA_whichVar+"_"+typeName),$("mLayDendrHist_"+LA_whichVar+"_"+typeName) vs LayerLabels as LA_whichVar+" layer hist"
	DoWindow/C $("LayerAnGr_"+typeName)
	ModifyGraph rgb($("mLayDendrHist_"+LA_whichVar+"_"+typeName))=(0,0,65535)
	Label left,LabelStr
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 typeName+"\r\\s(mLayAxonHist_"+LA_whichVar+"_"+typeName+") axon\r\\s(mLayDendrHist_"+LA_whichVar+"_"+typeName+") dendr"
	SetAxis/A/E=1 left
	ErrorBars $("mLayAxonHist_"+LA_whichVar+"_"+typeName) Y,wave=($("sLayAxonHist_"+LA_whichVar+"_"+typeName),)
	ErrorBars $("mLayDendrHist_"+LA_whichVar+"_"+typeName) Y,wave=($("sLayDendrHist_"+LA_whichVar+"_"+typeName),)
	ModifyGraph prescaleExp(left)=-3
	JT_AddResizeButton()

End

Function AddLayerBoundaries(typeName,addSoma)
	String		typeName
	Variable	addSoma
	
	// Add line denoting L5/L6 boundary
	WaveStats/Q $("Table_"+typeName+"_31")		// L5 thickness
	Variable	L5L6ypos = -V_avg
	SetDrawEnv ycoord= left,linefgc= (30583,30583,30583),dash= 1
	DrawLine 0,L5L6ypos,1,L5L6ypos
	
	// Add line denoting L23/L4 boundary
	WaveStats/Q $("Table_"+typeName+"_41")		// L4 thickness
	Variable	L23L4ypos = V_avg
	SetDrawEnv ycoord= left,linefgc= (30583,30583,30583),dash= 1
	DrawLine 0,L23L4ypos,1,L23L4ypos
	
	// Add line denoting L1/L23 boundary
	WaveStats/Q $("Table_"+typeName+"_42")		// L234 thickness
	Variable	L1L23ypos = V_avg
	if (V_npnts>0)										// Need at least one data point to estimate boundary between L1 and L2/3
		SetDrawEnv ycoord= left,linefgc= (30583,30583,30583),dash= 1
		DrawLine 0,L1L23ypos,1,L1L23ypos
		Variable/G L1L23ypos_store = L1L23ypos
	else													// If this data is not available for this graph, then use previous condition, if there is one, otherwise leave out
		if (exists("L1L23ypos_store"))
			NVAR	L1L23ypos_store
			SetDrawEnv ycoord= left,linefgc= (30583,30583,30583),dash= 1
			DrawLine 0,L1L23ypos_store,1,L1L23ypos_store
		endif
	endif
	
	// Add symbol denoting soma center
	if (addSoma)
		Make/O/N=(1) $("wSomaY"+typeName),$("wSomaYSEM"+typeName)
		WAVE	SomaY = $("wSomaY"+typeName)
		WAVE	SomaYSEM = $("wSomaYSEM"+typeName)
		WaveStats/Q $("Table_"+typeName+"_32")		// Soma y axis position
		SomaY[0] = V_avg
		SomaYSEM[1] = V_sdev/sqrt(V_npnts)
		AppendToGraph $("wSomaY"+typeName)
		ModifyGraph RGB($("wSomaY"+typeName))=(0,0,0)
		ErrorBars/T=0/L=0.5 $("wSomaY"+typeName),Y wave=($("wSomaYSEM"+typeName),$("wSomaYSEM"+typeName))
		ModifyGraph mode($("wSomaY"+typeName))=3,marker($("wSomaY"+typeName))=8,opaque($("wSomaY"+typeName))=1
	endif
	
End

Function ConvertOnceLoaded(Suff)
	String		Suff

	WAVE		wave3
	wave3 *= -1

	Duplicate/O wave0,$("compIndex"+Suff)
	Duplicate/O wave1,$("compType"+Suff)
	Duplicate/O wave2,$("xCoord"+Suff)
	Duplicate/O wave3,$("yCoord"+Suff)
	Duplicate/O wave4,$("zCoord"+Suff)
	Duplicate/O wave5,$("diam"+Suff)
	Duplicate/O wave6,$("linkedTo"+Suff)

End

Function ConvertLFOnceLoaded(Suff)
	String		Suff

	// Print "{ConvertLFOnceLoaded} working on converting layer-5 data."
	ConvertOnceLoaded("LF"+Suff)
	
	WAVE		wave3


End

Function ConvertExtOnceLoaded(Suff)
	String		Suff

	// Print "{ConvertExtOnceLoaded} working on converting extent-imaged data."
	ConvertOnceLoaded("Ext"+Suff)

End

Function GetNMDARsupp(fName)
	String		fName

	Variable	Amount = -1
	
	WAVE/T	wReconFileName
	WAVE		NMDASupp
	
	Variable	n = numpnts(NMDASupp)
	if (n!=numpnts(wReconFileName))
		print "Strange error in {GetNMDARsupp} -- number of file names and number of NMDAR supp entries do not match."
		Abort "Strange error in {GetNMDARsupp} -- number of file names and number of NMDAR supp entries do not match."
	endif
	Variable	i
	i = 0
	do
		if (StringMatch(wReconFileName[i],fName))
			Amount = NMDASupp[i]
//			print"\""+ fName+"\" NMDAR suppression is "+num2str(Amount)+"."
		endif
		i += 1
	while(i<n)
	
	if (Amount==-1)
		print "Strange error in {GetNMDARsupp} -- NMDAR supp for \""+fName+"\" was not found."
		Abort "Strange error in {GetNMDARsupp} -- NMDAR supp for \""+fName+"\" was not found."
	endif

	Return		Amount
	
End

Function ScaleThisRecon(fName,abortOnError)
	String		fName
	Variable	abortOnError

	Variable	doScaleIt = 0
	
	WAVE/T	wReconFileName
	WAVE		wPixPerMicron
	
	Variable	n = numpnts(wPixPerMicron)
	if (n!=numpnts(wReconFileName))
		print "Strange error in {ScaleThisRecon} -- number of file names and number of scaling entries do not match."
		Abort "Strange error in {ScaleThisRecon} -- number of file names and number of scaling entries do not match."
	endif
	Variable	i
	i = 0
	do
		if (StringMatch(wReconFileName[i],fName))
			doScaleIt = wPixPerMicron[i]
			print"\t\tWave point #"+num2str(i)+": \""+ fName+"\" should be scaled down by a factor of "+num2str(doScaleIt)+"."
		endif
		i += 1
	while(i<n)
	
	if (doScaleIt==0)
		if (abortOnError)
			print "Strange error in {ScaleThisRecon} -- Scaling for \""+fName+"\" is zero or was not found."
			Abort "Strange error in {ScaleThisRecon} -- Scaling for \""+fName+"\" is zero or was not found."
		else
			print "Scaling for \""+fName+"\" is zero or was not found. Using scale=1."
			doScaleIt = 1
		endif
	endif

	Return		doScaleIt
	
End

Function RotateThisRecon(fName)
	String		fName

	Variable	doRotateIt = 0
	
	WAVE/T	RotateWhich
	WAVE		RotateHowMuch
	
	Variable	n = numpnts(RotateHowMuch)
	if (n!=numpnts(RotateWhich))
		print "Strange error in {RotateThisRecon} -- number of file names and number of rotation angles in Rotation Table do not match."
		Abort "Strange error in {RotateThisRecon} -- number of file names and number of rotation angles in Rotation Table do not match."
	endif
	Variable	i
	i = 0
	do
		if ( (StringMatch(RotateWhich[i],fName)) %& (RotateHowMuch[i]!=0) )
			doRotateIt = RotateHowMuch[i]
			print"\t\tWave point #"+num2str(i)+": \""+ fName+"\" should be rotated by "+num2str(doRotateIt)+" degrees."
		endif
		i += 1
	while(i<n)
	
	if (doRotateIt==0)
		print"\t\tWave point #"+num2str(i)+": \""+ fName+"\" is not in the rotation table."
	endif

	Return		doRotateIt
	
End

Function LoadRecon()

	doLoadRecon("")

End

Function doLoadRecon(theName)
	String		theName

	Variable	loadSpecific = 0	
	if (StrLen(theName)>0)
		loadSpecific = 1
	endif

	String/G	fName
	String/G	pathName
	Variable 	Keys = GetKeyState(0)

	if (loadSpecific)
		fName = theName
		print "Loading \""+pathName+fName+"\""
		LoadWave/Q/G/D/N/O pathName+fName
	else
		if (Keys & 2^2)
			Print "\tYou pressed the Shift key. This means reload last reconstruction."
			print "Reloading \""+pathName+fName+"\""
			LoadWave/Q/G/D/N/O pathName+fName
		else
			// If a previous path exists, redirect to that path
			if (StrLen(pathName)>0)
				NewPath/O/Q/Z tempPath,pathName
				PathInfo/S tempPath
			endif
			LoadWave/Q/G/D/N/O
			print "Loaded:"+S_path+S_fileName
		endif
	endif
	
	if (V_flag==7)
		fName = S_fileName
		pathName = S_path
		if (Keys & 2^0)
			Print "\tYou pressed the Command key. This means simply draw reconstruction without quantifying it."
			ConvertOnceLoaded("")					// Convert coordinates of reconstruction
			SimplyDrawRecon("",-1)				// Just draw reconstruction 
		else
			Print "\tDrawing reconstrucion and also quantifying it."
			ConvertOnceLoaded("")					// Convert coordinates of reconstruction
			AnalyzeRecon("",-1)					// Analyze reconstruction 
		endif
		
	else
		Abort "Error loading reconstruction!"
	endif

End

Function/S FindLayerFile()

	SVAR		fName
	WAVE/T	 wReconFileName
	WAVE/T	 wLayerFileName
	
	Variable	n = numpnts(wReconFileName )
	if (numpnts(wLayerFileName )!=n)
		LayerMapTableToFront()
		print "Number of entries in wReconFileName andn wLayerFileName do not match up."
		Abort "Number of entries in wReconFileName andn wLayerFileName do not match up."
	endif
	String		LayerFileName = ""
	Variable	i
	i = 0
	do
		if (StringMatch(fName,wReconFileName[i]))
			LayerFileName = wLayerFileName[i]
//			print i
			i += Inf
		endif
		i += 1
	while(i<n)
	
	if (StringMatch("dummy",LayerFileName))
		LayerFileName = ""
		print "Dummy layer file"
	else
		String	PathToLayerFiles	
		if (StrLen(LayerFileName)>0)
			PathInfo home
			PathToLayerFiles = S_path+"L:"
			NewPath/O/Q LayerPath,PathToLayerFiles
			if (V_flag)
				print "Problem setting the LayerPath in {FindLayerFile}"
				Abort "Problem setting the LayerPath in {FindLayerFile}"
			endif
			LoadWave/Q/G/D/N/O/P=LayerPath LayerFileName
			if (V_flag!=7)
				print "Problem loading the LayerFile in {FindLayerFile}",LayerFileName
				Abort "Problem loading the LayerFile in {FindLayerFile}"
			else
				 // print "Found LayerFile!",V_flag
			endif
		endif
	endif
	
	Return		LayerFileName

End

Function/S FindExtentFile()

	SVAR		fName
	WAVE/T	 wReconFileName
	WAVE/T	 wExtentFileName
	
	Variable	n = numpnts(wReconFileName )
	if (numpnts(wExtentFileName )!=n)
		LayerMapTableToFront()
		print "Number of entries in wReconFileName andn wExtentFileName do not match up."
		Abort "Number of entries in wReconFileName andn wExtentFileName do not match up."
	endif
	String		ExtentFileName = ""
	Variable	i
	i = 0
	do
		if (StringMatch(fName,wReconFileName[i]))
			ExtentFileName = wExtentFileName[i]
			i += Inf
		endif
		i += 1
	while(i<n)

	if (StringMatch("dummy",ExtentFileName))
		ExtentFileName = ""
	else
		String	PathToExtentFiles	
		if (StrLen(ExtentFileName)>0)
			PathInfo home
			PathToExtentFiles = S_path+"Extent:"
			NewPath/O/Q ExtentPath,PathToExtentFiles
			if (V_flag)
				print "Problem setting the ExtentPath in {FindExtentFile}"
				Abort "Problem setting the ExtentPath in {FindExtentFile}"
			endif
			LoadWave/Q/G/D/N/O/P=ExtentPath ExtentFileName
			if (V_flag!=7)
				print "Problem loading the ExtentFile in {FindExtentFile}",ExtentFileName
				Abort "Problem loading the ExtentFile in {FindExtentFile}"
			else
				// print "Found ExtentFile!",V_flag
			endif
		endif
	endif
	
	Return		ExtentFileName

End

Function ExtendLayerData(xLF,yLF)
	WAVE		xLF,yLF
	
	NVAR		xMin
	NVAR		xMax
	
	Variable	layerScale = 1
	Variable	layerMin = xMin*layerScale
	Variable	layerMax = xMax*layerScale

	Duplicate/O xLF,xLFtemp
	Duplicate/O yLF,yLFtemp
	
	if (MOD(numpnts(xLF)+1,3)!=0)
		Print "Strange error in {ExtendLayerData}"
		Print NameOfWave(xLF),MOD(numpnts(xLF),3),numpnts(xLF)
		Abort "Strange error in {ExtendLayerData}"
	endif
	
	Variable	n = numpnts(xLF)
	Variable	i
	i = 0
	do
		
		xLFtemp[i+0] = layerMin
		yLFtemp[i+0] = extendLine(xLF[i+0],yLF[i+0],xLF[i+1],yLF[i+1],layerMin)
		xLFtemp[i+1] = layerMax
		yLFtemp[i+1] = extendLine(xLF[i+0],yLF[i+0],xLF[i+1],yLF[i+1],layerMax)

		i += 3
	while(i<n)

//	xLFtemp[0] = layerMin
//	yLFtemp[0] = extendLine(xLF[0],yLF[0],xLF[1],yLF[1],layerMin)
//	xLFtemp[1] = layerMax
//	yLFtemp[1] = extendLine(xLF[0],yLF[0],xLF[1],yLF[1],layerMax)
//
//	xLFtemp[3] = layerMin
//	yLFtemp[3] = extendLine(xLF[3],yLF[3],xLF[4],yLF[4],layerMin)
//	xLFtemp[4] = layerMax
//	yLFtemp[4] = extendLine(xLF[3],yLF[3],xLF[4],yLF[4],layerMax)
	
	Duplicate/O xLFtemp,$(NameOfWave(xLF))
	Duplicate/O yLFtemp,$(NameOfWave(yLF))

End

Function extendLine(x1,y1,x2,y2,xPos)
	Variable	x1,y1,x2,y2,xPos

	Variable	k,m
	
	k = (y1-y2)/(x1-x2)
	m = y1-k*x1					//	y = k*x + m   -->   m = y - k*x
	
	Return k*xPos+m

End

Function thereAreSomaComps(compType,SomaCompType)
	WAVE		compType
	Variable	SomaCompType
	
	Variable	yesThereAre = 0
	
	Variable	n = numpnts(compType)
	Variable	i
	i = 0
	do
		if (compType[i]==SomaCompType)
			yesThereAre = 1
			i += Inf
		endif
		i += 1
	while(i<n)
	
	Return yesThereAre

End

////////////////////////////////////////////////////////////////////////////////////////////////////
//// Draw reconstruction without analyzing it

Function SimplyDrawRecon(typeName,tableIndex)
	String		typeName
	Variable	tableIndex
	
	String		Suff = ""
	if (StrLen(typeName)!=0)
		Suff = "_"+typeName+"_"+num2str(tableIndex+1)
	endif

	SVAR		fName

	WAVE		compIndex = $("compIndex"+Suff)
	WAVE		compType = $("compType"+Suff)
	WAVE		xCoord = $("xCoord"+Suff)
	WAVE		yCoord = $("yCoord"+Suff)
	WAVE		zCoord = $("zCoord"+Suff)
	WAVE		diam = $("diam"+Suff)
	WAVE		linkedTo = $("linkedTo"+Suff)

	Duplicate/O compType,$("compType2"+Suff)
	WAVE		compType2 = $("compType2"+Suff)
	Duplicate/O xCoord,$("xCoord2"+Suff)
	WAVE		xCoord2 = $("xCoord2"+Suff)
	Duplicate/O yCoord,$("yCoord2"+Suff)
	WAVE		yCoord2 = $("yCoord2"+Suff)
	Duplicate/O zCoord,$("zCoord2"+Suff)
	WAVE		zCoord2 = $("zCoord2"+Suff)
	
	// Find Soma centre and align
	Variable	ScaleBy = ScaleThisRecon(fName,0)				// Force no abort on error (user may not know scale of swc file initially)
	Variable	n = numpnts(diam)
	Variable	i
	Variable	thresDiam = 3
	Variable/G	AxonCompType = 2
	Variable/G	SomaCompType = AxonCompType-1
	Variable/G	DendrCompType = AxonCompType+1
	// 1 - SOMA
	// 2 - AXON
	// 3 - BASAL DENDRITES

	Make/O/N=(0)	SomaX,SomaY
	Variable	nSomaPoints = 0
	if (thereAreSomaComps(compType,SomaCompType))
		// Find soma compartments based on manual tagging of compartment as 'soma'
		print "This reconstruction has manually tagged somatic compartments."
		i = 0
		do
			if (compType[i]==SomaCompType)
//				print "\tSoma point:",i+1
				SomaX[nSomaPoints] = {xCoord[i]}
				SomaY[nSomaPoints] = {yCoord[i]}
				nSomaPoints += 1
				compType2[i]=SomaCompType
			else
				if (compType[i]!=AxonCompType)
					compType2[i] = DendrCompType
				endif
			endif
			i += 1
		while(i<n)
	else
		// Find soma compartments based on supracritical compartment diameter
		print "Searching for somatic compartments."
		i = 0
		do
			if ((diam[i]/ScaleBy>thresDiam) %& (compType[i]!=2))
//				print "\tSoma point:",i+1
				SomaX[nSomaPoints] = {xCoord[i]}
				SomaY[nSomaPoints] = {yCoord[i]}
				nSomaPoints += 1
				compType2[i]=SomaCompType
			else
				if (compType[i]!=AxonCompType)
					compType2[i] = DendrCompType
				endif
			endif
			i += 1
		while(i<n)
	endif
	if (nSomaPoints==0)
		print "Fatal error: Found no soma points."
		Abort "Fatal error: Found no soma points."
	endif

	// Make nice reconstruction drawing
	MakeNiceRecon(Suff)
	Variable	doAppend = 0	//( (tableIndex!=-1) %& (tableIndex!=0))
	ShowReconstruction(Suff,doAppend,0,0,"",0)		// no x offset, no recon name to be shown
	
End

Function AnalyzeRecon(typeName,tableIndex)
	String		typeName
	Variable	tableIndex
	
	String		Suff = ""
	if (StrLen(typeName)!=0)
		Suff = "_"+typeName+"_"+num2str(tableIndex+1)
	endif

	// Try to find a file that indicates the coordinates of the neocortical layers
	String/G	Layer_fName = ""
	Variable/G	LF_Exists = 0
	Layer_fName = FindLayerFile()
	if (StrLen(Layer_fName)>0)
		// print "LayerFile exists -- converting loaded layer data..."
		LF_Exists = 1
		ConvertLFOnceLoaded(Suff)		// y axis is inverted in my analysis compared to Neuromantic: up is positive
	else
		print "Cannot find LayerFile..."
		LF_Exists = 0
//		Abort "Cannot find LayerFile -- terminating analysis..."
	endif

	// Try to find a file that indicates the extent of the slice that was imaged
	String/G	Extent_fName = ""
	Variable/G	Extent_Exists = 0
	Extent_fName = FindExtentFile()
	if (StrLen(Extent_fName)>0)
		// print "ExtentFile exists -- converting loaded layer data..."
		Extent_Exists = 1
		ConvertExtOnceLoaded(Suff)		// y axis is inverted in my analysis compared to Neuromantic: up is positive
	else
		print "Cannot find ExtentFile..."
		Extent_Exists = 0
//		Abort "Cannot find ExtentFile -- terminating analysis..."
	endif

	// Manage morphology data
	SVAR		fName
	
	Make/O/N=(7) $("xCenters"+Suff),$("yCenters"+Suff)
	WAVE		xCenters = $("xCenters"+Suff)
	WAVE		yCenters = $("yCenters"+Suff)
	xCenters = NaN
	yCenters = NaN
	Make/O/N=(7) $("CenterTags"+Suff)
	WAVE		CenterTags = $("CenterTags"+Suff)
	Make/T/O/N=(7) $("CenterTagsT"+Suff)
	WAVE/T	CenterTagsT = $("CenterTagsT"+Suff)
	CenterTags = x
	CenterTagsT = {"A","D","a","d","cA","cD","s"}

	WAVE		compIndex = $("compIndex"+Suff)
	WAVE		compType = $("compType"+Suff)
	WAVE		xCoord = $("xCoord"+Suff)
	WAVE		yCoord = $("yCoord"+Suff)
	WAVE		zCoord = $("zCoord"+Suff)
	WAVE		diam = $("diam"+Suff)
	WAVE		linkedTo = $("linkedTo"+Suff)

	Duplicate/O compType,$("compType2"+Suff)
	WAVE		compType2 = $("compType2"+Suff)
	Duplicate/O xCoord,$("xCoord2"+Suff)
	WAVE		xCoord2 = $("xCoord2"+Suff)
	Duplicate/O yCoord,$("yCoord2"+Suff)
	WAVE		yCoord2 = $("yCoord2"+Suff)
	Duplicate/O zCoord,$("zCoord2"+Suff)
	WAVE		zCoord2 = $("zCoord2"+Suff)
	
	// Manage extent-imaged data
	if (Extent_Exists)
		WAVE		xCoordExt = $("xCoord"+"Ext"+Suff)
		WAVE		yCoordExt = $("yCoord"+"Ext"+Suff)
		Duplicate/O xCoordExt,$("xCoord2"+"Ext"+Suff)
		WAVE		xCoord2Ext = $("xCoord2"+"Ext"+Suff)
		Duplicate/O yCoordExt,$("yCoord2"+"Ext"+Suff)
		WAVE		yCoord2Ext = $("yCoord2"+"Ext"+Suff)
	else
		Make/O/N=(5) dummy_xExt = {-200,200,-200,200}
		Make/O/N=(5) dummy_yExt = {-100,-100,100,100}
		WAVE		xCoordExt = dummy_xExt
		WAVE		yCoordExt = dummy_yExt
		WAVE		xCoord2Ext = dummy_xExt
		WAVE		yCoord2Ext = dummy_yExt
	endif

	// Manage layerFile data
	if (LF_Exists)
		WAVE		xCoordLF = $("xCoord"+"LF"+Suff)
		WAVE		yCoordLF = $("yCoord"+"LF"+Suff)
		if (MOD(numpnts(xCoordLF),2)!=0)
			print "Number of points in LayerFile is uneven! "+num2str(numpnts(xCoordLF))+" -- xCoord"+"LF"+Suff
			Abort "Number of points in LayerFile is uneven! "+num2str(numpnts(xCoordLF))+" -- xCoord"+"LF"+Suff
		else
			// print "Found useful LayerData"
		endif
		Variable	nLayerBoundaries = numpnts(xCoordLF)/2		// Note that numpnts is changed by NaNs inserted by ProcessLayerData
		ProcessLayerData(xCoordLF,yCoordLF)						// This sorts the layers in the right order
//		if (nLayerBoundaries==3)									// L1/23 boundary is missing --> use extent imaged data to recreate this boundary
//			RecreateL123Boundary(xCoordLF,yCoordLF,xCoordExt,yCoordExt)
//		endif
		Duplicate/O xCoordLF,$("xCoord2"+"LF"+Suff)				// xCoord is "original", those ending with "2" are modified copies
		WAVE		xCoord2LF = $("xCoord2"+"LF"+Suff)
		Duplicate/O yCoordLF,$("yCoord2"+"LF"+Suff)
		WAVE		yCoord2LF = $("yCoord2"+"LF"+Suff)
	else
		Make/O/N=(5) dummy_xLF = {-200,200,NaN,-200,200}
		Make/O/N=(5) dummy_yLF = {-100,-100,NaN,100,100}
		WAVE		xCoordLF = dummy_xLF
		WAVE		yCoordLF = dummy_yLF
		WAVE		xCoord2LF = dummy_xLF
		WAVE		yCoord2LF = dummy_yLF
	endif
	
	// Find Soma centre and align
	Variable	ScaleBy = ScaleThisRecon(fName,1)					// Abort on error
	Variable	n = numpnts(diam)
	Variable	i
	Variable	thresDiam = 3
	Variable/G	AxonCompType = 2
	Variable/G	SomaCompType = AxonCompType-1
	Variable/G	DendrCompType = AxonCompType+1
	// 1 - SOMA
	// 2 - AXON
	// 3 - BASAL DENDRITES

	Make/O/N=(0)	SomaX,SomaY
	Variable	nSomaPoints = 0
	if (thereAreSomaComps(compType,SomaCompType))
		// Find soma compartments based on manual tagging of compartment as 'soma'
		// print "This reconstruction has manually tagged somatic compartments."
		i = 0
		do
			if (compType[i]==SomaCompType)
//				print "\tSoma point:",i+1
				SomaX[nSomaPoints] = {xCoord[i]}
				SomaY[nSomaPoints] = {yCoord[i]}
				nSomaPoints += 1
				compType2[i]=SomaCompType
			else
				if (compType[i]!=AxonCompType)
					compType2[i] = DendrCompType
				endif
			endif
			i += 1
		while(i<n)
	else
		// Find soma compartments based on supracritical compartment diameter
//		print "WARNING! Searching for somatic compartments."
		i = 0
		do
//			if ((diam[i]/ScaleBy>thresDiam) %& (compType[i]!=2))
			if (diam[i]/ScaleBy>thresDiam)
//				print "\tSoma point:",i+1
//				SomaX[nSomaPoints] = {xCoord[i]/ScaleBy}			// Bugfix 2020-08-17 JSj, I forgot to add "/ScaleBy" at the end...
//				SomaY[nSomaPoints] = {yCoord[i]/ScaleBy}			// ... thus putting the average SomaYCenter in the wrong location! (although stats were executed right)
				SomaX[nSomaPoints] = {xCoord[i]}						// Bugfix 2021-06-17 JSj, the above "bugfix" actually caused the problem. Rectifying that here.
				SomaY[nSomaPoints] = {yCoord[i]}	
				nSomaPoints += 1
				compType2[i]=SomaCompType
			else
				if (compType[i]!=AxonCompType)
					compType2[i] = DendrCompType
				endif
			endif
			i += 1
		while(i<n)
	endif
	if (nSomaPoints==0)
		print "Fatal error: Found no soma points."
		Abort "Fatal error: Found no soma points."
//	else
//		print "Found "+num2str(nSomaPoints)+" soma points."
	endif
	WaveStats/Q SomaX
	Variable	SomaXCenter = V_avg
	WaveStats/Q SomaY
	Variable/G	SomaYCenter = V_avg
//	Print "Soma center:",SomaXCenter,SomaYCenter
//	Print "nSoma points",nSomaPoints
	xCoord2 -= SomaXCenter							// Morphology
	yCoord2 -= SomaYCenter
	if (LF_Exists)
		xCoord2LF -= SomaXCenter							// Layer boundaries
		yCoord2LF -= SomaYCenter
	endif
	if (Extent_Exists)
		xCoord2Ext -= SomaXCenter							// Extent imaged
		yCoord2Ext -= SomaYCenter
	endif
	SomaXCenter = 0									// Soma is now in the middle -- redefine accordingly
	SomaYCenter = 0

	// Scale reconstruction
	xCoord2 /= ScaleBy
	yCoord2 /= ScaleBy
	zCoord2 /= ScaleBy
	diam /= ScaleBy									// Warning! Scaling compartment size!
	if (LF_Exists)
		xCoord2LF /= ScaleBy
		yCoord2LF /= ScaleBy
	endif
	if (Extent_Exists)
		xCoord2Ext /= ScaleBy
		yCoord2Ext /= ScaleBy
	endif
	
	// Extract amount of NMDAR suppression
	Variable/G	NMDARSuppVal = GetNMDARsupp(fName)
	
	// Rotate reconstruction
	Variable	doRotateIt = RotateThisRecon(fName)
	if (doRotateIt)
		RotateRecon(doRotateIt,Suff)		// Only operates on xCoord2 and yCoord2
		if (LF_Exists)
			RotateRecon(doRotateIt,"LF"+Suff)	// Also rotate layer file
		endif
		if (Extent_Exists)
			RotateRecon(doRotateIt,"Ext"+Suff)	// Also rotate extent-imaged file
		endif
	endif
	
	// Extend layers
	if (LF_Exists)
		ExtendLayerData(xCoord2LF,yCoord2LF)
	endif

	// Find L5 thickness
	Variable/G	L5thickness = 0
	Variable/G	L4thickness = 0
	Variable/G	L234thickness = 0
	if (LF_Exists)
		L5thickness = FindL4L5Boundary(xCoord2LF,yCoord2LF)-FindL5L6Boundary(xCoord2LF,yCoord2LF)
		L4thickness = FindL23L4Boundary(xCoord2LF,yCoord2LF)-FindL4L5Boundary(xCoord2LF,yCoord2LF)
		L234thickness = FindL1L23Boundary(xCoord2LF,yCoord2LF)-FindL4L5Boundary(xCoord2LF,yCoord2LF)
	endif
	
	// Align on L4/L5 boundary?
	Variable	L4L5boundary
	NVAR		AlignOnL4L5
	Duplicate/O $("xCoord2"+Suff),$("xSholl"+Suff)	// when aligning on L4/L5 boundary, keep soma-aligned coords for Sholl analysis
	Duplicate/O $("yCoord2"+Suff),$("ySholl"+Suff)
	WAVE		xCoord2Sh = $("xSholl"+Suff)
	WAVE		yCoord2Sh = $("ySholl"+Suff)
	if (AlignOnL4L5)
		if (LF_Exists)
			L4L5boundary = FindL4L5Boundary(xCoord2LF,yCoord2LF)
		else
			L4L5boundary = 0
		endif
		yCoord2 -= L4L5boundary
		yCoord2LF -= L4L5boundary
		if (Extent_Exists)
			yCoord2Ext -= L4L5boundary
		endif
		SomaYCenter -= L4L5boundary
	endif
	
	// Find Axon, Dendrite, and soma cloud centers
	Make/O/N=(0)	AxonX,AxonY,AxonShollX,AxonShollY
	Variable	nAxonPoints = 0
	Make/O/N=(0)	DendrX,DendrY,DendrShollX,DendrShollY
	Variable	nDendrPoints = 0
	i = 0
	do
		if (compType[i] == 2)			// 3 = dendrite & Axon, 2 = axon
			AxonX[nAxonPoints] = {xCoord2[i]}
			AxonY[nAxonPoints] = {yCoord2[i]}
			AxonShollX[nAxonPoints] = {xCoord2Sh[i]}		// For Sholl analysis, always align on soma
			AxonShollY[nAxonPoints] = {yCoord2Sh[i]}
			nAxonPoints += 1
		else
			if (compType2[i]!=SomaCompType)
				DendrX[nDendrPoints] = {xCoord2[i]}
				DendrY[nDendrPoints] = {yCoord2[i]}
				DendrShollX[nDendrPoints] = {xCoord2Sh[i]}
				DendrShollY[nDendrPoints] = {yCoord2Sh[i]}
				nDendrPoints += 1
			endif
		endif
		i += 1
	while(i<n)
	
	// Axon center
	WaveStats/Q AxonX
	Variable	AxonXCenter = V_avg
	WaveStats/Q AxonY
	Variable	AxonYCenter = V_avg

	// Do Sholl analysis
	DoSholl(AxonShollX,AxonShollY)
	Duplicate/O nCrossingsWave,$("Axon_Xings"+Suff)
	Duplicate/O radiusWave,$("Axon_radius"+Suff)
	NVAR	DendriteMax
	NVAR	CriticalRadius
	Variable/G	AxonMaxVal = DendriteMax
	Variable/G	AxonCritR = CriticalRadius
	DoSholl(DendrShollX,DendrShollY)
	Duplicate/O nCrossingsWave,$("Dendr_Xings"+Suff)
	Duplicate/O radiusWave,$("Dendr_radius"+Suff)
	Variable/G	DendrMaxVal = DendriteMax
	Variable/G	DendrCritR = CriticalRadius
	
	// Find Axon compartment with max distance
	Duplicate/O AxonX,$("compAxonDist"+Suff)
	WAVE		compAxonDist = $("compAxonDist"+Suff)
	compAxonDist = sqrt(AxonX^2+AxonY^2)
	WaveStats/Q compAxonDist
	Variable/G	maxAxonDistComp = V_maxloc
	Variable/G	maxAxonDist = V_max
	Variable/G	maxAxonDistCompX = AxonX[maxAxonDistComp]
	Variable/G	maxAxonDistCompY = AxonY[maxAxonDistComp]
	Variable/G	maxAxonDistCompAngle = atan2(maxAxonDistCompY,maxAxonDistCompX)*180/Pi
	xCenters[2] = maxAxonDistCompX
	yCenters[2] = maxAxonDistCompY

	// Find Dendr cloud center
	WaveStats/Q DendrX
	Variable	DendrXCenter = V_avg
	WaveStats/Q DendrY
	Variable	DendrYCenter = V_avg

	// Find Dendr compartment with max distance
	Duplicate/O DendrX,$("compDendrDist"+Suff)
	WAVE		compDendrDist = $("compDendrDist"+Suff)
	compDendrDist = sqrt(DendrX^2+DendrY^2)
	WaveStats/Q compDendrDist
	Variable/G	maxDendrDistComp = V_maxloc
	Variable/G	maxDendrDist = V_max
	Variable/G	maxDendrDistCompX = DendrX[maxDendrDistComp]
	Variable/G	maxDendrDistCompY = DendrY[maxDendrDistComp]
	Variable/G	maxDendrDistCompAngle = atan2(maxDendrDistCompY,maxDendrDistCompX)*180/Pi
	xCenters[3] = maxDendrDistCompX
	yCenters[3] = maxDendrDistCompY

	Variable/G	SomaRelXCenter = (SomaXCenter - 0)
	Variable/G	SomaRelYCenter = (SomaYCenter - 0)
	xCenters[6] = SomaRelXCenter
	yCenters[6] = SomaRelYCenter

	Variable/G	AxonRelXCenter = (AxonXCenter - 0)
	Variable/G	AxonRelYCenter = (AxonYCenter - 0)
	Variable/G	AxonCenterDist = sqrt(AxonXCenter^2+AxonYCenter^2)
	Variable/G	AxonAngle = atan2(AxonYCenter,AxonXCenter)*180/Pi
	xCenters[0] = AxonRelXCenter
	yCenters[0] = AxonRelYCenter
	Variable/G	DendrRelXCenter = (DendrXCenter - 0)
	Variable/G	DendrRelYCenter = (DendrYCenter - 0)
	Variable/G	DendrCenterDist = sqrt(DendrXCenter^2+DendrYCenter^2)
	Variable/G	DendrAngle = atan2(DendrYCenter,DendrXCenter)*180/Pi
	xCenters[1] = DendrRelXCenter
	yCenters[1] = DendrRelYCenter
	
	// Find convex hulls & analyze
	Variable/G	AreaAboveL5
	Variable/G	AreaAboveL4
	Variable/G	PercAreaAboveL5
	Variable/G	PercAreaAboveL4
	Variable/C	Center
	FindConvexHull(AxonX,AxonY)
	WaveStats/Q	cHullX
	Variable/G	AxonHullWidth = V_max-V_min
	WaveStats/Q	cHullY
	Variable/G	AxonHullHeight = V_max-V_min
	Duplicate/O cHullX,$("Axon_cHullX"+Suff)
	Duplicate/O cHullY,$("Axon_cHullY"+Suff)
	Center = CenterHull(cHullX,cHullY,"Axon",xCoord2LF,yCoord2LF)		// This also creates the matrix map of the convex hull
	Variable/G	AxonHullCenterX = real(Center)
	Variable/G	AxonHullCenterY = imag(Center)
	Variable/G	AxonAreaAboveL5 = AreaAboveL5							// CenterHull calculates this
	Variable/G	AxonAreaAboveL4 = AreaAboveL4							// CenterHull calculates this
	Variable/G	PercAxonAreaAboveL5 = PercAreaAboveL5					// CenterHull calculates this
	Variable/G	PercAxonAreaAboveL4 = PercAreaAboveL4					// CenterHull calculates this
	xCenters[4] = AxonHullCenterX
	yCenters[4] = AxonHullCenterY

	FindConvexHull(DendrX,DendrY)
	Duplicate/O cHullX,$("Dendr_cHullX"+Suff)
	Duplicate/O cHullY,$("Dendr_cHullY"+Suff)
	WaveStats/Q	cHullX
	Variable/G	DendrHullWidth = V_max-V_min
	WaveStats/Q	cHullY
	Variable/G	DendrHullHeight = V_max-V_min
	Center = CenterHull(cHullX,cHullY,"Dendr",xCoord2LF,yCoord2LF)		// This also creates the matrix map of the convex hull
	Variable/G	DendrHullCenterX = real(Center)
	Variable/G	DendrHullCenterY = imag(Center)
	Variable/G	DendrAreaAboveL5 = AreaAboveL5							// CenterHull calculates this
	Variable/G	DendrAreaAboveL4 = AreaAboveL4							// CenterHull calculates this
	Variable/G	PercDendrAreaAboveL5 = PercAreaAboveL5					// CenterHull calculates this
	Variable/G	PercDendrAreaAboveL4 = PercAreaAboveL4					// CenterHull calculates this
	xCenters[5] = DendrHullCenterX
	yCenters[5] = DendrHullCenterY
	
	// Distance from soma to L4 and to L6?
	Variable/G	L4dist = 0
	Variable/G	L6dist = 0
	if (LF_Exists)
		L4dist = DistToLine(SomaXCenter,SomaYCenter,xCoord2LF[0],yCoord2LF[0],xCoord2LF[1],yCoord2LF[1])
		L6dist = DistToLine(SomaXCenter,SomaYCenter,xCoord2LF[3],yCoord2LF[3],xCoord2LF[4],yCoord2LF[4])
	endif

	// Maximum distance above granular cell layer
	// Axon
	WaveStats/Q AxonY
	Variable/G	maxAxonYAboveL4 = V_max-L4thickness			// This is stricly speaking an approximation that is only valid when layer lines are approximately horizontally oriented
	// Dendrites
	WaveStats/Q DendrY
	Variable/G	maxDendrYAboveL4 = V_max-L4thickness			// This is stricly speaking an approximation that is only valid when layer lines are approximately horizontally oriented

	// Amount of branching above L4/L5 boundary?
	Variable/G	percAxonAboveL5 = 0
	Variable/G	percDendrAboveL5 = 0
	if (LF_Exists)
		percAxonAboveL5 = PercSegmentsAboveL5(AxonX,AxonY,xCoord2LF,yCoord2LF)
		percDendrAboveL5 = PercSegmentsAboveL5(DendrX,DendrY,xCoord2LF,yCoord2LF)
	endif
	
	// Amount of branching above L2/3-L4?
	Variable/G	percAxonAboveL4 = 0
	Variable/G	percDendrAboveL4 = 0
	if (LF_Exists)
		percAxonAboveL4 = PercSegmentsAboveL4(AxonX,AxonY,xCoord2LF,yCoord2LF)
		percDendrAboveL4 = PercSegmentsAboveL4(DendrX,DendrY,xCoord2LF,yCoord2LF)
	endif
	
	// Analyze imaged-extent data
	Variable/G	extX = 0
	Variable/G	extY = 0
	Variable/G	extYAboveOrig = 0
	if (Extent_Exists)
		WaveStats/Q xCoord2Ext
		extX = V_max-V_min
		WaveStats/Q yCoord2Ext
		extY = V_max-V_min
		extYAboveOrig = V_max
	endif
	
	// Make nice reconstruction drawing
	MakeNiceRecon(Suff)
	Variable	doAppend = ( (tableIndex!=-1) %& (tableIndex!=0))
	ShowReconstruction(Suff,doAppend,0,0,"",1)		// no x offset, no recon name to be shown
	
	// Make nice Sholl analysis drawing
	ShowSholl(Suff,doAppend)

	// Analyze for branching in different layers
	if (LF_Exists)
		LayerAnalysis(Suff)
		if (tableIndex==-1)
			ShowLayerAnalysis()
		endif
		WAVE	LayAxonHist_Size = $("LayAxonHist_Size"+Suff)
		WAVE	LayDendrHist_Size = $("LayDendrHist_Size"+Suff)
	endif
	Variable/G	axonLenAboveL4 = 0
	Variable/G	dendrLenAboveL4 = 0
	if (LF_Exists)
		axonLenAboveL4 = LayAxonHist_Size[3]+LayAxonHist_Size[4]//+LayAxonHist_Size[2]
		dendrLenAboveL4 = LayDendrHist_Size[3]+LayDendrHist_Size[4]//+LayDendrHist_Size[2]
	endif

	// Report data
	if (tableIndex==-1)
		Print "//// For compartments:"
		Print "Axon center:",AxonXCenter,AxonYCenter
		Print "nAxon points",nAxonPoints
		Print "Dendr center:",DendrXCenter,DendrYCenter
		Print "nDendr points",nDendrPoints
		Print "Absolute Axon center relative to Soma center / MAX:",AxonRelXCenter,AxonRelYCenter,"/",maxAxonDistCompX,maxAxonDistCompY
		Print "Euclidian distance Axon center - Soma center / MAX:",AxonCenterDist,"/",maxAxonDist
		Print "Axon Angle / MAX:",AxonAngle,"/",maxAxonDistCompAngle
		Print "Absolute Dendr center relative to Soma center / MAX:",DendrRelXCenter,DendrRelYCenter,"/",maxDendrDistCompX,maxDendrDistCompY
		Print "Euclidian distance Dendr center - Soma center / MAX:",DendrCenterDist,"/",maxDendrDist
		Print "Dendr Angle / MAX:",DendrAngle,"/",maxDendrDistCompAngle
		Print "Maximum compartment distance above L4 boundary (axon):",maxAxonYAboveL4
		Print "Maximum compartment distance above L4 boundary (dendrite):",maxDendrYAboveL4
		Print "//// For hull:"
		Print "Axon center relative to soma:",AxonHullCenterX,AxonHullCenterY
		Print "Axon hull width/height:",AxonHullWidth,AxonHullHeight
		Print "Dendr center relative to soma:",DendrHullCenterX,DendrHullCenterY
		Print "Dendr hull width/height:",DendrHullWidth,DendrHullHeight
		Print "Distance from soma center to L4:",L4dist
		Print "Distance from soma center to L6:",L6dist
		Print "Percent of axon above L5:",percAxonAboveL5,"%"
		Print "Percent of dendrite above L5:",percDendrAboveL5,"%"
		Print "Percent of axon above L4:",percAxonAboveL4,"%"
		Print "Percent of dendrite above L4:",percDendrAboveL4,"%"
		Print "Axon hull area above L5:",AxonAreaAboveL5,"micron^2"
		Print "Dendrite hull area above L5:",DendrAreaAboveL5,"micron^2"
		Print "Percentage axon hull area above L5:",PercAxonAreaAboveL5,"%"
		Print "Percentage dendrite hull area above L5:",PercDendrAreaAboveL5,"%"
		Print "Axon hull area above L4:",AxonAreaAboveL4,"micron^2"
		Print "Dendrite hull area above L4:",DendrAreaAboveL4,"micron^2"
		Print "Percentage axon hull area above L4:",PercAxonAreaAboveL4,"%"
		Print "Percentage dendrite hull area above L4:",PercDendrAreaAboveL4,"%"
		Print "Layer 5 thickness:",L5thickness,"µm"
		Print "Layer 4 thickness:",L4thickness,"µm"
		Print "Layer 234 thickness:",L234thickness,"µm"
		Print "Soma Y center:",SomaYCenter,"µm"
		Print "Axon Max:",AxonMaxVal,"crossings"
		Print "Axon critical radius:",AxonCritR,"µm"
		Print "Dendr Max:",DendrMaxVal,"crossings"
		Print "Dendr critical radius:",DendrCritR,"µm"
		Print "NMDAR supp:",NMDARSuppVal,"%"
		Print "Imaged extent along x axis:",extX,"µm"
		Print "Imaged extent along y axis:",extY,"µm"
		Print "Imaged extent along y axis *above the origin*:",extYAboveOrig,"µm"
		Print "Total axon length above L5:",axonLenAboveL4/1e3,"mm"
		Print "Total dendrite length above L5:",dendrLenAboveL4/1e3,"mm"
	endif

	// Put data in clipboard	
	String	ScrapStr = fName+"\t"

	// Put data in table if relevant
	String/G	VarStr = ""
	VarStr += "AxonRelXCenter;"
	VarStr += "AxonRelYCenter;"
	VarStr += "AxonCenterDist;"
	VarStr += "AxonAngle;"

	VarStr += "DendrRelXCenter;"
	VarStr += "DendrRelYCenter;"
	VarStr += "DendrCenterDist;"
	VarStr += "DendrAngle;"

	VarStr += "maxAxonDistCompX;"
	VarStr += "maxAxonDistCompY;"
	VarStr += "maxAxonDist;"
	VarStr += "maxAxonDistCompAngle;"

	VarStr += "maxDendrDistCompX;"
	VarStr += "maxDendrDistCompY;"
	VarStr += "maxDendrDist;"
	VarStr += "maxDendrDistCompAngle;"

	VarStr += "AxonHullCenterX;"
	VarStr += "AxonHullCenterY;"
	VarStr += "AxonHullWidth;"
	VarStr += "AxonHullHeight;"

	VarStr += "DendrHullCenterX;"
	VarStr += "DendrHullCenterY;"
	VarStr += "DendrHullWidth;"
	VarStr += "DendrHullHeight;"

	VarStr += "L4dist;"
	VarStr += "L6dist;"
	VarStr += "percAxonAboveL5;"
	VarStr += "percDendrAboveL5;"
	VarStr += "AxonAreaAboveL5;"
	VarStr += "DendrAreaAboveL5;"
	
	VarStr += "L5thickness;"
	VarStr += "SomaYCenter;"

	VarStr += "AxonMaxVal;"
	VarStr += "AxonCritR;"
	VarStr += "DendrMaxVal;"
	VarStr += "DendrCritR;"
	
	VarStr += "NMDARSuppVal;"

	VarStr += "extX;"
	VarStr += "extY;"
	VarStr += "extYAboveOrig;"

	VarStr += "L4thickness;"
	VarStr += "L234thickness;"

	VarStr += "axonLenAboveL4;"
	VarStr += "dendrLenAboveL4;"
	
	VarStr += "maxAxonYAboveL4;"
	VarStr += "maxDendrYAboveL4;"
	
	VarStr += "AxonAreaAboveL4;"
	VarStr += "DendrAreaAboveL4;"

	VarStr += "PercAxonAreaAboveL5;"
	VarStr += "PercDendrAreaAboveL5;"
	VarStr += "PercAxonAreaAboveL4;"
	VarStr += "PercDendrAreaAboveL4;"

	VarStr += "percAxonAboveL4;"
	VarStr += "percDendrAboveL4;"

	i = 0
	n = ItemsInList(VarStr)
	String		currVar
	do
		currVar = StringFromList(i,VarStr)
		try
			NVAR	theVar = $currVar
		catch
			print currVar+" does not seem to exist!"
			Abort currVar+" does not seem to exist!"
		endtry
		ScrapStr += num2str(theVar)
		if (i!=n-1)
			ScrapStr += "\t"
		endif
		if (tableIndex!=-1)
			WAVE/Z	tableWave = $("Table_"+typeName+"_"+num2str(i+1))
			tableWave[tableIndex] = theVar
			if (tableIndex==numpnts(tableWave)-1)
				DoWindow $("theTable_"+typeName)
				if (V_flag)
					ModifyTable/W=$("theTable_"+typeName) title($("Table_"+typeName+"_"+num2str(i+1)))=currVar
				endif
			endif
		endif
		i += 1
	while(i<n)
	
	if (tableIndex==-1)
		print ScrapStr
//		PutScrapText ScrapStr
	endif
	
End

Function FindL1L23Boundary(xLF,yLF)
	WAVE		xLF,yLF
	
	// There might be no boundary marked between L1 and L2/3 in cases where we did not image that high up
	Variable	noInfo = 0
	if (numpnts(xLF)<10)
		noInfo = 1
	endif
	
	Variable	x1 = xLF[9]
	Variable	y1 = yLF[9]

	Variable	x2 = xLF[10]
	Variable	y2 = yLF[10]
	
	Variable	k = (y2-y1)/(x2-x1)
	Variable	m = y1-k*x1
	
	if (noInfo)
		m = NaN
	endif
	
	Return		m

End

Function FindL23L4Boundary(xLF,yLF)
	WAVE		xLF,yLF
	
	Variable	x1 = xLF[6]
	Variable	y1 = yLF[6]

	Variable	x2 = xLF[7]
	Variable	y2 = yLF[7]
	
	Variable	k = (y2-y1)/(x2-x1)
	Variable	m = y1-k*x1
	
	Return		m

End

Function FindL4L5Boundary(xLF,yLF)
	WAVE		xLF,yLF
	
	Variable	x1 = xLF[0]
	Variable	y1 = yLF[0]

	Variable	x2 = xLF[1]
	Variable	y2 = yLF[1]
	
	Variable	k = (y2-y1)/(x2-x1)
	Variable	m = y1-k*x1
	
	Return		m

End

Function FindL5L6Boundary(xLF,yLF)
	WAVE		xLF,yLF
	
	Variable	x1 = xLF[3]
	Variable	y1 = yLF[3]

	Variable	x2 = xLF[4]
	Variable	y2 = yLF[4]
	
	Variable	k = (y2-y1)/(x2-x1)
	Variable	m = y1-k*x1
	
	Return		m

End

Function ModifyShollPlot(typeName)
	String		typeName

	DoWindow/F ShollPlot

	String		traceList = WaveList("Axon_Xings*",";","WIN:ShollPlot")
	Variable	n = ItemsInList(traceList)
//	String		currAxonTrace,currDendrTrace
	Variable	i,j

	Duplicate/O $("Axon_radius_"+typeName+"_1"),$("ShollX_"+typeName)
	Duplicate/O $("Axon_Xings_"+typeName+"_1"),$("AxonShollY_"+typeName),$("AxonShollYSEM_"+typeName)
	Duplicate/O $("Dendr_Xings_"+typeName+"_1"),$("DendrShollY_"+typeName),$("DendrShollYSEM_"+typeName)
	WAVE	AxonShollY = $("AxonShollY_"+typeName)
	WAVE	DendrShollY = $("DendrShollY_"+typeName)
	WAVE	AxonShollYSEM = $("AxonShollYSEM_"+typeName)
	WAVE	DendrShollYSEM = $("DendrShollYSEM_"+typeName)
	Variable	nPoints = numpnts(AxonShollY)
	Make/O/N=(n) workWave1,workWave2

	// Calculate means + SEM
	j = 0
	do
		i = 0
		do
			WAVE	w1 = $("Axon_Xings_"+typeName+"_"+num2str(i+1))
			WAVE	w2 = $("Dendr_Xings_"+typeName+"_"+num2str(i+1))
			workWave1[i] = w1[j]
			workWave2[i] = w2[j]
			i += 1
		while(i<n)
		WaveStats/Q workWave1
		AxonShollY[j] = V_avg
		AxonShollYSEM[j] = V_sdev/sqrt(V_npnts)
		WaveStats/Q workWave2
		DendrShollY[j] = V_avg
		DendrShollYSEM[j] = V_sdev/sqrt(V_npnts)
		j += 1
	while(j<nPoints)
	
	// Create -SEM and +SEM waves
	Duplicate/O AxonShollY,$("AxonShollYnegSEM_"+typeName),$("AxonShollYposSEM_"+typeName)
	WAVE	AxonShollYnegSEM = $("AxonShollYnegSEM_"+typeName)
	WAVE	AxonShollYposSEM = $("AxonShollYposSEM_"+typeName)
	AxonShollYnegSEM = AxonShollY-AxonShollYSEM
	AxonShollYposSEM = AxonShollY+AxonShollYSEM
	Duplicate/O DendrShollY,$("DendrShollYnegSEM_"+typeName),$("DendrShollYposSEM_"+typeName)
	WAVE	DendrShollYnegSEM = $("DendrShollYnegSEM_"+typeName)
	WAVE	DendrShollYposSEM = $("DendrShollYposSEM_"+typeName)
	DendrShollYnegSEM = DendrShollY-DendrShollYSEM
	DendrShollYposSEM = DendrShollY+DendrShollYSEM
	
	// Modify the graph
	Variable RemoveTraces = 1
	i = 0
	do
		WAVE	w1 = $("Axon_Xings_"+typeName+"_"+num2str(i+1))
		WAVE	w2 = $("Dendr_Xings_"+typeName+"_"+num2str(i+1))
		if (RemoveTraces)
			ModifyGraph hideTrace($("Axon_Xings_"+typeName+"_"+num2str(i+1)))=1
			ModifyGraph hideTrace($("Dendr_Xings_"+typeName+"_"+num2str(i+1)))=1
		else
			ModifyGraph hideTrace($("Axon_Xings_"+typeName+"_"+num2str(i+1)))=0
			ModifyGraph hideTrace($("Dendr_Xings_"+typeName+"_"+num2str(i+1)))=0
			ModifyGraph/W=ShollPlot RGB($("Axon_Xings_"+typeName+"_"+num2str(i+1)))=(65535,49151,49151)
			ModifyGraph/W=ShollPlot RGB($("Dendr_Xings_"+typeName+"_"+num2str(i+1)))=(49151,49151,65535)
		endif
		i += 1
	while(i<n)
	
	Variable eBars = 0
	Variable colMul = 0.8
	
	if (StrLen(WaveList("DendrShollY_SOM",";","WIN:ShollPlot"))==0)		// Do not append if already in the graph
		if (!(eBars))
			AppendToGraph/W=ShollPlot $("DendrShollYposSEM_"+typeName) vs $("ShollX_"+typeName)
			AppendToGraph/W=ShollPlot $("DendrShollYnegSEM_"+typeName) vs $("ShollX_"+typeName)
			ModifyGraph mode($("DendrShollYposSEM_"+typeName))=7
			ModifyGraph mode($("DendrShollYnegSEM_"+typeName))=7
			ModifyGraph lSize($("DendrShollYposSEM_"+typeName))=0
			ModifyGraph lSize($("DendrShollYnegSEM_"+typeName))=0
			ModifyGraph rgb($("DendrShollYposSEM_"+typeName))=(65535,65535*colMul,65535)
			ModifyGraph hbFill($("DendrShollYposSEM_"+typeName))=2
			ModifyGraph toMode($("DendrShollYposSEM_"+typeName))=1
			AppendToGraph/W=ShollPlot $("AxonShollYposSEM_"+typeName) vs $("ShollX_"+typeName)
			AppendToGraph/W=ShollPlot $("AxonShollYnegSEM_"+typeName) vs $("ShollX_"+typeName)
			ModifyGraph mode($("AxonShollYposSEM_"+typeName))=7
			ModifyGraph mode($("AxonShollYnegSEM_"+typeName))=7
			ModifyGraph lSize($("AxonShollYposSEM_"+typeName))=0
			ModifyGraph lSize($("AxonShollYnegSEM_"+typeName))=0
			ModifyGraph rgb($("AxonShollYposSEM_"+typeName))=(65535,65535,65535*colMul)//(65535*colMul,65535,65535)
			ModifyGraph hbFill($("AxonShollYposSEM_"+typeName))=2
			ModifyGraph toMode($("AxonShollYposSEM_"+typeName))=1
		endif
		AppendToGraph/W=ShollPlot $("DendrShollY_"+typeName) vs $("ShollX_"+typeName)
		AppendToGraph/W=ShollPlot $("AxonShollY_"+typeName) vs $("ShollX_"+typeName)
		if (eBars)
			ErrorBars/W=ShollPlot/T=0 $("DendrShollY_"+typeName),Y wave=($("DendrShollYSEM_"+typeName),$("DendrShollYSEM_"+typeName))
			ErrorBars/W=ShollPlot/T=0 $("AxonShollY_"+typeName),Y wave=($("AxonShollYSEM_"+typeName),$("AxonShollYSEM_"+typeName))
		endif
		ModifyGraph/W=ShollPlot RGB($("DendrShollY_"+typeName))=(65535,0,65535)
		ModifyGraph/W=ShollPlot RGB($("AxonShollY_"+typeName))=(65535,50000,3600)
		ModifyGraph lsize($("DendrShollY_"+typeName))=2
		ModifyGraph lsize($("AxonShollY_"+typeName))=2
	endif
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\s("+"AxonShollY_"+typeName+") axon\r\\s("+"DendrShollY_"+typeName+") dendr"
	ModifyGraph nticks(left)=3

End

Function ShowSholl(Suff,AppendFlag)
	String		Suff
	Variable	AppendFlag

	Variable	xPos = 21+250+40
	Variable	yPos = 76
	Variable	Width = 320
	Variable	Height = 200
	
	SVAR		fName

	if (AppendFlag)
		DoWindow/F ShollPlot
		DoWindow/T ShollPlot,"Sholl analysis"
	else
		DoWindow/K ShollPlot
		Display /W=(xPos,yPos,xPos+Width,yPos+Height) as "Sholl "+fName
		DoWindow/C ShollPlot
	endif
	AppendToGraph/W=ShollPlot $("Axon_Xings"+Suff) vs $("Axon_radius"+Suff)
	AppendToGraph/W=ShollPlot $("Dendr_Xings"+Suff) vs $("Dendr_radius"+Suff)
	ModifyGraph RGB($("Dendr_Xings"+Suff))=(0,0,65535)
	label left,"number of crossings"
	label bottom,"radius (µm)"
	SetAxis/A/N=1 left
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\s("+"Axon_Xings"+Suff+") axon\r\\s("+"Dendr_Xings"+Suff+") dendr"

End

Function DoSholl(wX,wY)
	WAVE		wX
	WAVE		wY
	
	Variable	nPoints = numpnts(wX)
	
	Make/O/C/N=(nPoints) PolarCoords
	Make/O/N=(nPoints) Polar_r,Polar_Phi
	
	PolarCoords = r2polar(cmplx(wX,wY))
	Polar_r = real(PolarCoords)
	Polar_Phi=Imag(PolarCoords)

	Variable	nSteps = 100			// nBins for Sholl graph
	Variable	rMax = 650
	Variable	delta = rMax/nSteps
	Variable	curr_r = 0
	Variable	nBranchCrossings
	Make/O/N=(nSteps) nCrossingsWave,radiusWave
	Variable	i,j
	i = 0
	do
		curr_r = i*delta+delta/2
		nBranchCrossings = 0
		j = 0
		do
			if ( ( (Polar_r[j]<curr_r) %& (Polar_r[j+1]>curr_r) ) %|  ( (Polar_r[j]>curr_r) %& (Polar_r[j+1]<curr_r) ) )
				nBranchCrossings += 1
			endif
			j += 1
		while(j<nPoints-1)
		nCrossingsWave[i] = nBranchCrossings
		radiusWave[i] = curr_r
		i += 1
	while(i<nSteps)
	
	WaveStats/Q nCrossingsWave
	Variable/G	DendriteMax = V_max
	Variable/G	CriticalRadius = radiusWave[V_maxloc]

end

Function RecreateL123Boundary(xCoordLF,yCoordLF,xCoordExt,yCoordExt)
	WAVE		xCoordLF,yCoordLF,xCoordExt,yCoordExt
	
//	Print "{RecreateL123Boundary} as adding another layer"
	
	Variable	maxDist = 0
	
	Variable	x0
	Variable	y0
	Variable	lastLayer

	lastLayer = numpnts(xCoordLF)-2
	Variable	x1 = xCoordLF[lastLayer]		// get coordinates of last layer
	Variable	y1 = yCoordLF[lastLayer]
	Variable	x2 = xCoordLF[lastLayer+1]
	Variable	y2 = yCoordLF[lastLayer+1]
	
	Variable	k = (y2-y1)/(x2-x1)			// Slope of last layer
	Variable	m = y1-k*x1					// Intercept of last layer
	
	print x1,y1,x2,y2,k,m

	xCoordLF[numpnts(xCoordLF)] = {NaN}		// add another layer after last layer
	yCoordLF[numpnts(yCoordLF)] = {NaN}

	xCoordLF[numpnts(xCoordLF)] = {NaN}
	yCoordLF[numpnts(yCoordLF)] = {NaN}

	xCoordLF[numpnts(xCoordLF)] = {NaN}
	yCoordLF[numpnts(yCoordLF)] = {NaN}

	lastLayer = numpnts(xCoordLF)-2
	
	Variable	i
	Variable	n = numpnts(xCoordExt)
	
	i = 0
	do
		x0 = xCoordExt[i]
		y0 = yCoordExt[i]
		if (AboveLine(x0,y0,x1,y1,x2,y2))					// If this extent imaged point is above the last layer...
//			print "{RecreateL123Boundary} debug text dump:",AboveLine(x0,y0,x1,y1,x2,y2),x0,y0,DistToLine(x0,y0,x1,y1,x2,y2)
			if (DistToLine(x0,y0,x1,y1,x2,y2)>maxDist)		// ... and if it is farthest away...
				maxDist = DistToLine(x0,y0,x1,y1,x2,y2)
				m = y0-k*(x0-100)							// ...the set coordinates of *new* last layer to a line that goes through this point
				xCoordLF[lastLayer] = x0-100
				yCoordLF[lastLayer] = k*(x0-100)+m
				xCoordLF[lastLayer+1] = x0+100
				yCoordLF[lastLayer+1] = k*(x0+100)+m
			endif
		endif
		i += 1
	while(i<n)
	
	if (JT_isNaN(xCoordLF[lastLayer]))
		print "Strange error in {RecreateL123Boundary}: Could not recreate last layer."
//		Abort "Strange error in {RecreateL123Boundary}: Could not recreate last layer."
	endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	This function sorts the layer data so we start with L5/L6 boundary
////	BUT we then swap L5/L6 and L4/L5 boundaries over. The final order is thus:
////		1	L4/L5
////		2	L5/L6
////		3	L23/L4
////		4	L1/L23 (if applicable)
////	Note that there are NaN's between layers, to enable plotting with gaps. And each layer takes two coordinates
////	so for each coordinate we have
////		0,1,2		L4/L5
////		3,4,5		L5/L6
////		6,7,8		L23/L4
////		9,10,11	L1/L23 (if applicable)

Function ProcessLayerData(xCoordLF,yCoordLF)
	WAVE		xCoordLF,yCoordLF
	
	Duplicate/O xCoordLF,tempxLF
	Duplicate/O yCoordLF,tempyLF

	Variable	n = numpnts(xCoordLF)
	Variable	v
	Variable	x1,x2,y1,y2
	Variable	notDone
	Variable	i,j
	
	// Ascending insertion sort algorithm, from Wikipedia
	// Pairwise sorting of data with respect to y axis coordinate, so that information start with the most positive coordinates (the L5/L6 boundary)
	i = 2
	do
		v = (yCoordLF[i]+yCoordLF[i+1])/2
		y1 = yCoordLF[i]
		y2 = yCoordLF[i+1]
		x1 = xCoordLF[i]
		x2 = xCoordLF[i+1]
		j = i - 2
		notDone = 1
		do
			if ((yCoordLF[j]+yCoordLF[j+1])/2>v)		// probably not necessary to work on the average, but just in case slice was weirdly rotated
				yCoordLF[j+2] = yCoordLF[j]
				yCoordLF[j+2+1] = yCoordLF[j+1]
				xCoordLF[j+2] = xCoordLF[j]
				xCoordLF[j+2+1] = xCoordLF[j+1]
				j -= 2
				if (j<0)
					notDone = 0
				endif
			else
				notDone = 0
			endif
		while (notDone)
		yCoordLF[j+2] = y1
		yCoordLF[j+2+1] = y2
		xCoordLF[j+2] = x1
		xCoordLF[j+2+1] = x2
		i += 2
	while(i<n)

	// For backwards compatibility with rest of analysis, flip data over for L4/L5 and L5/L6 boundaries, keeping everything else sorted
	TurnLayerDataOver(xCoordLF,yCoordLF)
	
	// Insert NaNs between layer boundaries, to enable plotting
	i = 2
	j = 0
	do
		InsertPoints i+j,1,xCoordLF,yCoordLF
		xCoordLF[i+j] = NaN
		yCoordLF[i+j] = NaN
		j += 1	// count inserted points
		i += 2	// count each coordinate pair
	while(i<n)

End

Function TurnLayerDataOver(xCoordLF,yCoordLF)
	WAVE		xCoordLF,yCoordLF
	
	// print "{TurnLayerDataOver} is working",yCoordLF

	Duplicate/O xCoordLF,workWave
	xCoordLF[2] = xCoordLF[0]
	xCoordLF[3] = xCoordLF[1]
	xCoordLF[0] = workWave[2]
	xCoordLF[1] = workWave[3]

	Duplicate/O yCoordLF,workWave
	yCoordLF[2] = yCoordLF[0]
	yCoordLF[3] = yCoordLF[1]
	yCoordLF[0] = workWave[2]
	yCoordLF[1] = workWave[3]

End

Function PercSegmentsAboveL5(AxonX,AxonY,xLF,yLF)
	WAVE		AxonX,AxonY,xLF,yLF

	Variable	n = numpnts(AxonX)
	Variable	i
	Variable	nAbove = 0
	i = 0
	do
		if (AboveLine(AxonX[i],AxonY[i],xLF[0],yLF[0],xLF[1],yLF[1]))
			nAbove += 1
		endif
		i += 1
	while(i<n)
	
	Variable	PercAbove = nAbove/n*100
	Return		PercAbove

End

Function PercSegmentsAboveL4(AxonX,AxonY,xLF,yLF)
	WAVE		AxonX,AxonY,xLF,yLF

	Variable	n = numpnts(AxonX)
	Variable	i
	Variable	nAbove = 0
	i = 0
	do
		if (AboveLine(AxonX[i],AxonY[i],xLF[6],yLF[6],xLF[7],yLF[7]))
			nAbove += 1
		endif
		i += 1
	while(i<n)
	
	Variable	PercAbove = nAbove/n*100
	Return		PercAbove

End

Function BelowLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0					// point to be tested
	Variable	x1,y1,x2,y2			// line

	Return		(!(AboveLine(x0,y0,x1,y1,x2,y2)))

End

Function AboveLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0					// point to be tested
	Variable	x1,y1,x2,y2			// line

	Variable		above
	
	above = (y0 - y1)*(x2-x1) - (x0 - x1)*(y2- y1)
	
	above *= sign(x2-x1)
	
	above = above > 0
	
	Return		above

end

Function DistToLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0,x1,y1,x2,y2

//	http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
//	
//	line is given by (x1,y1) to (x2,y2)
//	point is given by (x0,y0)
//	
//	d = abs((x2-x1)*(y1-y0)-(x1-x0)*(y2-y1))/sqrt((x2-x1)^2+(y2-y1)^2)

	Variable	d = abs((x2-x1)*(y1-y0)-(x1-x0)*(y2-y1))/sqrt((x2-x1)^2+(y2-y1)^2)

	Return		d

End

Function DistTo3DPoint(x0,y0,z0,x1,y1,z1)
	Variable	x0,y0,z0
	Variable	x1,y1,z1

	Variable	d = abs(sqrt((x1-x0)^2+(y1-y0)^2+(z1-z0)^2))

	Return		d

End

////////////////////////////////////////////////////////////////////////////////////////
// Analyze for branching into different cortical layers

Function LayerAnalysis(Suff) //,AppendFlag)
	String		Suff
//	Variable	AppendFlag

	Variable	normalize = 0				// Boolean: Normalize size measure to bin with maximum
	
	WAVE	compIndex = $("compIndex"+Suff)
//	WAVE	compType = $("compType"+Suff)
	WAVE	xCoord2 = $("xCoord2"+Suff)
	WAVE	yCoord2 = $("yCoord2"+Suff)
	WAVE	diam = $("diam"+Suff)
	WAVE	linkedTo = $("linkedTo"+Suff)
	WAVE	compType2 = $("compType2"+Suff)
	
	WAVE	xCoord2LF = $("xCoord2"+"LF"+Suff)
	WAVE	yCoord2LF = $("yCoord2"+"LF"+Suff)

	NVAR	AxonCompType
	NVAR	SomaCompType
	NVAR	DendrCompType

	Make/O/T/N=(5)	LayerLabels = {"L6","L5","L4","L2/3","L1"}
	Make/O/N=(5)		$("LayAxonHist_Size"+Suff),$("LayAxonHist_N"+Suff),$("LayAxonHist_Bool"+Suff)
	Make/O/N=(5)		$("LayDendrHist_Size"+Suff),$("LayDendrHist_N"+Suff),$("LayDendrHist_Bool"+Suff)
	WAVE	LayAxonHist_Size = $("LayAxonHist_Size"+Suff)
	WAVE	LayAxonHist_N = $("LayAxonHist_N"+Suff)
	WAVE	LayAxonHist_Bool = $("LayAxonHist_Bool"+Suff)
	WAVE	LayDendrHist_Size = $("LayDendrHist_Size"+Suff)
	WAVE	LayDendrHist_N = $("LayDendrHist_N"+Suff)
	WAVE	LayDendrHist_Bool = $("LayDendrHist_Bool"+Suff)
	LayAxonHist_Size = 0
	LayAxonHist_N = 0
	LayAxonHist_Bool = 0
	LayDendrHist_Size = 0
	LayDendrHist_N = 0
	LayDendrHist_Bool = 0

	Variable	x1_below,x2_below,y1_below,y2_below
	Variable	x1_above,x2_above,y1_above,y2_above
	
	// L4/L5, L5/L6, L23/L4, and L1/L23 if applicable
	Make/O/N=(4) layerInfoOrder = {1,0,2,3}

	Variable	nComps = numpnts(diam)
	Variable	nLayers = Ceil(numpnts(xCoord2LF)/3)
	Variable	cumulAxonS = 0
	Variable	cumulAxonN = 0
	Variable	cumulDendrS = 0
	Variable	cumulDendrN = 0
	Variable	i	// i counts compartments
	Variable	j	// j counts layers
	j = 0
	do
		if (j>0)
			x1_below = xCoord2LF[layerInfoOrder[j-1]*3]
			x2_below = xCoord2LF[layerInfoOrder[j-1]*3+1]
			y1_below = yCoord2LF[layerInfoOrder[j-1]*3]
			y2_below = yCoord2LF[layerInfoOrder[j-1]*3+1]
		else
			x1_below = xCoord2LF[layerInfoOrder[0]*3]
			x2_below = xCoord2LF[layerInfoOrder[0]*3+1]
			y1_below = yCoord2LF[layerInfoOrder[0]*3]-1000			// create "fake" layer below L6
			y2_below = yCoord2LF[layerInfoOrder[0]*3+1]-1000
		endif
		if (j<nLayers)
			x1_above = xCoord2LF[layerInfoOrder[j]*3]
			x2_above = xCoord2LF[layerInfoOrder[j]*3+1]
			y1_above = yCoord2LF[layerInfoOrder[j]*3]
			y2_above = yCoord2LF[layerInfoOrder[j]*3+1]
		else
			x1_above = xCoord2LF[layerInfoOrder[j-1]*3]
			x2_above = xCoord2LF[layerInfoOrder[j-1]*3+1]
			y1_above = yCoord2LF[layerInfoOrder[j-1]*3]+1000		// create "fake" layer above the last layer
			y2_above = yCoord2LF[layerInfoOrder[j-1]*3+1]+1000
		endif
		cumulAxonS = 0
		cumulAxonN = 0
		cumulDendrS = 0
		cumulDendrN = 0
		i = 0
		do
			if (compType2[i]==AxonCompType)
				if (AboveLine(xCoord2[i],yCoord2[i],x1_below,y1_below,x2_below,y2_below))
					if (BelowLine(xCoord2[i],yCoord2[i],x1_above,y1_above,x2_above,y2_above))
						cumulAxonS +=  sqrt((yCoord2[i]-yCoord2[i-1])^2+(xCoord2[i]-xCoord2[i-1])^2)
						cumulAxonN += 1
					endif
				endif
			else
				if (compType2[i]==DendrCompType)
					if (AboveLine(xCoord2[i],yCoord2[i],x1_below,y1_below,x2_below,y2_below))
						if (BelowLine(xCoord2[i],yCoord2[i],x1_above,y1_above,x2_above,y2_above))
							cumulDendrS += sqrt((yCoord2[i]-yCoord2[i-1])^2+(xCoord2[i]-xCoord2[i-1])^2)
							cumulDendrN += 1
						endif
					endif
				else
					// Ignore soma
				endif
			endif
			i += 1
		while(i<nComps)
		LayAxonHist_Size[j] = cumulAxonS
		LayAxonHist_N[j] = cumulAxonN
		LayAxonHist_Bool[j] = (cumulAxonN>0)
		LayDendrHist_Size[j] = cumulDendrS
		LayDendrHist_N[j] = cumulDendrN
		LayDendrHist_Bool[j] = (cumulDendrN>0)
		j += 1
	while(j<nLayers+1)
	
	WAVE LayDendrHist_Size_Casp6_WT_1
	
	if (normalize)
		Variable	maxVal
		WaveStats/Q LayAxonHist_Size
		maxVal = LayAxonHist_Size[V_maxloc]
		LayAxonHist_Size /= maxVal
		LayAxonHist_Size *= 100
		WaveStats/Q LayDendrHist_Size
		maxVal = LayDendrHist_Size[V_maxloc]
		LayDendrHist_Size /= maxVal
		LayDendrHist_Size *= 100
	endif

End

Function ShowLayerAnalysis()

	DoWindow/K LayerAnGr1
	Display LayAxonHist_Size,LayDendrHist_Size vs LayerLabels as "Compartment size"
	DoWindow/C LayerAnGr1
	ModifyGraph rgb(LayDendrHist_Size)=(0,0,65535)
	Label left "compartment length"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\s(LayAxonHist_Size) axon\r\\s(LayDendrHist_Size) dendr"
	SetAxis/A/E=1 left

	DoWindow/K LayerAnGr2
	Display LayAxonHist_N,LayDendrHist_N vs LayerLabels as "# of compartments"
	DoWindow/C LayerAnGr2
	ModifyGraph rgb(LayDendrHist_N)=(0,0,65535)
	Label left "# compartments"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\s(LayAxonHist_N) axon\r\\s(LayDendrHist_N) dendr"
	SetAxis/A/E=1 left

	DoWindow/K LayerAnGr3
	Display LayAxonHist_Bool,LayDendrHist_Bool vs LayerLabels as "Boolean"
	DoWindow/C LayerAnGr3
	ModifyGraph rgb(LayDendrHist_Bool)=(0,0,65535)
	Label left "boolean"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\s(LayAxonHist_Bool) axon\r\\s(LayDendrHist_Bool) dendr"
	SetAxis/A/E=1 left
	
	JT_ArrangeGraphs2(";;;;;;LayerAnGr1;LayerAnGr2;LayerAnGr3;",3,4)

End

Function findNearestColor(X,Y,Z)
	Variable	X,Y,Z
	
	WAVE		dendColX
	WAVE		dendColY
	WAVE		dendColZ
	WAVE		dendColV
	
	Variable	n = numpnts(dendColV)
	Variable	i,dist

	Make/O/N=(n) distW,indexW
	
	i = 0
	do
		distW[i] = DistTo3DPoint(X,Y,Z,dendColX[i],dendColY[i],dendColZ[i])
		indexW[i] = i
		i += 1
	while(i<n)
	
//	Sort distW,distW,indexW
	Sort distW,indexW
	
	return dendColV[indexW[0]]

End

////////////////////////////////////////////////////////////////////////////////////////
// Reformat reconstruction data and also make density maps

Function MakeNiceRecon(Suff)
	String		Suff
	
//	Print "{MakeNiceRecon} Suffix is \""+Suff+"\""

	NVAR	AxonCompType
	NVAR	xMin,xMax,yMin,yMax

	Variable	doColorizeMorph = 0
	if (Exists("dendColV"))
		doColorizeMorph = 1
		Make/O/N=(0) morphColW
		Variable	morphColCounter = 0
	endif

	Variable	doSmoothMap = 1
	if (StrLen(Suff)==0)
		doSmoothMap = 0
//		Print "Not making smooth map..."
	endif
	
	Variable	doProperRecon = 1
	Make/O/N=1 $("properX_axon"+suff),$("properY_axon"+suff)
	Make/O/N=1 $("properX_dend"+suff),$("properY_dend"+suff)
	WAVE	properX_axon = $("properX_axon"+suff)
	WAVE	properY_axon = $("properY_axon"+suff)
	WAVE	properX_dend = $("properX_dend"+suff)
	WAVE	properY_dend = $("properY_dend"+suff)
	properX_axon = {0}
	properY_axon = {0}
	properX_dend = {0}
	properY_dend = {0}
	Make/O/N=2 xLimits,yLimits
	xLimits = {xMin,xMax}
	yLimits = {yMin,yMax}

	Variable	doMirror = 1

	WAVE	AxonMatrix2
	WAVE	DendrMatrix2

	WAVE	compIndex = $("compIndex"+Suff)
//	WAVE	compType = $("compType"+Suff)
	WAVE	xCoord2 = $("xCoord2"+Suff)
	WAVE	yCoord2 = $("yCoord2"+Suff)
	WAVE	zCoord2 = $("zCoord2"+Suff)
	WAVE	diam = $("diam"+Suff)
	WAVE	linkedTo = $("linkedTo"+Suff)
	WAVE	compType2 = $("compType2"+Suff)
	
	Variable	xNow,yNow,aNow
	Variable	pNow,qNow,paNow,qaNow
	Variable	p1,p2,q1,q2
//	Variable	gaussDiam = 5
	Variable	gaussDiam = 25
	Variable	fillScale = 3
	

	Variable	n = numpnts(diam)
	Variable	i

	make/O/N=(0)	$("drawX"+Suff)
	make/O/N=(0)	$("drawY"+Suff)
	make/O/N=(0)	$("drawD"+Suff)
	make/O/N=(0)	$("drawCT"+Suff)
	make/O/N=(0)	$("drawSize"+Suff)
	
	WAVE	drawX = $("drawX"+Suff)
	WAVE	drawY = $("drawY"+Suff)
	WAVE	drawD = $("drawD"+Suff)
	WAVE	drawCT = $("drawCT"+Suff)
	WAVE	drawSize = $("drawSize"+Suff)
	
	Variable	compCounter = 0
	i = 0
	do
		if (LinkedTo[i]==-1)							// Starting a new branch
			drawX[compCounter] = {NaN}
			drawY[compCounter] = {NaN}
			drawD[compCounter] = {NaN}
			drawCT[compCounter] = {NaN}
			drawSize[compCounter] = {NaN}
			compCounter += 1
			drawX[compCounter] = {xCoord2[i]}
			drawY[compCounter] = {yCoord2[i]}
			drawD[compCounter] = {diam[i]}
			drawCT[compCounter] = {compType2[i]}
			drawSize[compCounter] = {NaN}
			compCounter += 1
		else
			if (LinkedTo[i]!=compIndex[i-1])			// This segment is not linked to previous segment in list but elsewhere in tree
				drawX[compCounter] = {NaN}
				drawY[compCounter] = {NaN}
				drawD[compCounter] = {NaN}
				drawCT[compCounter] = {NaN}
				drawSize[compCounter] = {NaN}
				compCounter += 1
				drawX[compCounter] = {xCoord2[LinkedTo[i]-1]}
				drawY[compCounter] = {yCoord2[LinkedTo[i]-1]}
				drawD[compCounter] = {diam[LinkedTo[i]-1]}
				drawCT[compCounter] = {compType2[LinkedTo[i]-1]}
				drawSize[compCounter] = {NaN}
				compCounter += 1
			endif
			drawX[compCounter] = {xCoord2[i]}
			drawY[compCounter] = {yCoord2[i]}
			drawD[compCounter] = {diam[i]}
			drawCT[compCounter] = {compType2[i]}
			drawSize[compCounter] = {CalcCompSize(compCounter,Suff)}
			// Make proper reconstruction drawing
			if (doProperRecon)
				if (drawCT[compCounter]==AxonCompType)
					WAVE	properX = $("properX_axon"+suff)
					WAVE	properY = $("properY_axon"+suff)
				else
					WAVE	properX = $("properX_dend"+suff)
					WAVE	properY = $("properY_dend"+suff)
					if (doColorizeMorph)
						morphColW[numpnts(morphColW)] = {findNearestColor(xCoord2[i],yCoord2[i],zCoord2[i])}
						newSegment(drawX[compCounter-1],drawY[compCounter-1],drawD[compCounter-1],drawX[compCounter],drawY[compCounter],drawD[compCounter],morphColCounter)
						morphColCounter += 1
					endif
				endif
				appendSegment(drawX[compCounter-1],drawY[compCounter-1],drawD[compCounter-1],drawX[compCounter],drawY[compCounter],drawD[compCounter],properX,properY)
			endif
			// Make smoothed MatrixMap
			if (doSmoothMap)
				if (drawCT[compCounter]==AxonCompType)
					WAVE		theMatrix = AxonMatrix2
				else
					WAVE		theMatrix = DendrMatrix2
				endif
				xNow = (drawX[compCounter]+drawX[compCounter-1])/2
				yNow = (drawY[compCounter]+drawY[compCounter-1])/2
				aNow = drawSize[compCounter]
				pNow = (xNow - DimOffset(theMatrix, 0))/DimDelta(theMatrix,0)
				qNow = (yNow - DimOffset(theMatrix, 1))/DimDelta(theMatrix,1)
//				paNow = aNow/DimDelta(theMatrix,0)*gaussDiam
//				qaNow = aNow/DimDelta(theMatrix,1)*gaussDiam
				paNow = 1/DimDelta(theMatrix,0)*gaussDiam
				qaNow = 1/DimDelta(theMatrix,1)*gaussDiam
				p1 = Round(pNow-paNow*fillScale)
				p2 = Round(pNow+paNow*fillScale)
				q1 = Round(qNow-qaNow*fillScale)
				q2 = Round(qNow+qaNow*fillScale)
//				theMatrix[p1,p2][q1,q2] += exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
				theMatrix[p1,p2][q1,q2] += aNow*exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
				// Create mirror image too
				if (doMirror)
					xNow *= -1
					pNow = (xNow - DimOffset(theMatrix, 0))/DimDelta(theMatrix,0)
					p1 = Round(pNow-paNow*fillScale)
					p2 = Round(pNow+paNow*fillScale)
//					theMatrix[p1,p2][q1,q2] += exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
					theMatrix[p1,p2][q1,q2] += aNow*exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
				endif
			endif
			compCounter += 1
		endif
		i += 1
	while(i<n)
	
End

Function CalcCompSize(index,Suff)
	Variable	index
	String		Suff
	
	NVAR		whatIsCompSize
	
	WAVE	drawX = $("drawX"+Suff)
	WAVE	drawY = $("drawY"+Suff)
	WAVE	drawD = $("drawD"+Suff)
	
	if (index==0)
		Print "Strange error in CalcCompSize: Index is zero."
		Abort "Strange error in CalcCompSize: Index is zero."
	endif
	
	Variable	compLen = sqrt((drawY[index]-drawY[index-1])^2+(drawX[index]-drawX[index-1])^2)
	// Area of an Isosceles Trapezoid
	Variable	compArea = (drawD[index]+drawD[index-1])/2*compLen
	Variable	compSize

	switch(whatIsCompSize)
		case 1:
			compSize = compArea
			break
		case 2:
			compSize = compLen
			break
		default:
			print "{CalcCompSize} weird error"
			Abort "{CalcCompSize} weird error"
	endswitch

	Return		compSize

End

Function setCompSize(theMode)
	Variable	theMode
	
	NVAR		whatIsCompSize
	whatIsCompSize = theMode
	
	switch(theMode)
		case 1:
			print "Mode is compartment area"
			break
		case 2:
			print "Mode is compartment length"
			break
		default:
			print "Mode is compartment area"
			whatIsCompSize = 1
	endswitch

End

Function FindAxonConvexHull()

	WAVE		AxonX,AxonY

	FindConvexHull(AxonX,AxonY)

end

Function FindConvexHull(xWave,yWave)
	WAVE		xWave,yWave
	
	// Set up
//	print "=== Finding Convex Hull ==="
//	print NameOfWave(xWave),NameOfWave(yWave)
	
	Make/O/N=(0)	cHullX,cHullY
	Variable	nHullCounter = 0
	Variable	minAngleLoc
	Variable	presentX,presentY,firstX,firstY,firstIndex,presentIndex,lastAngle,lastIndex
	lastIndex = -1
	
	// Find coordinates with minimum y and minium x -- this is our starting point
	WaveStats/Q	yWave
	presentX = xWave[V_minloc]
	presentY = yWave[V_minloc]
	presentIndex = V_minloc
	firstIndex = V_minloc
	firstX = presentX
	firstY = presentY
	lastAngle = 0
	
	Variable	n = numpnts(xWave)
	Variable	i
	Make/D/O/N=(n)	tempAngles

	// Perform Jarvis walk
	do
		cHullX[nHullCounter] = {presentX}
		cHullY[nHullCounter] = {presentY}
		nHullCounter += 1
	
		// Find angles from present point to all other points
		tempAngles = NaN
		i = 0
		do
			if (i!=presentIndex)
				tempAngles[i] = atan2(yWave[i]-presentY,xWave[i]-presentX)*180/Pi
				if (tempAngles[i]<0)		// Ensure wrap-around of negative angles
					tempAngles[i] = 360+tempAngles[i]
				endif
			endif
			i += 1
		while(i<n)
		// Located next point with minimum angle -- this is our next point
		tempAngles = tempAngles[p]< lastAngle ? NaN : tempAngles[p]
		WaveStats/Q tempAngles
		lastAngle = V_min
		presentX = xWave[V_minloc]
		presentY = yWave[V_minloc]
		if (lastIndex!=V_minloc)
			presentIndex = V_minloc
			lastIndex = presentIndex
		else
			print "Algorithm is stuck at point "+num2str(lastIndex)+"   ("+num2str(presentX)+","+num2str(presentY)+")"
			print "This can happen if there is literally only one compartment type of a given kind. For example, "
			print "if you have precisely one compartment of the Axon type, then the Jarvis Walk used to create"
			print "the axon convex hull cannot execute correctly, because there is not enough data for the algorithm"
			print "to complete. A solution is to add one more coordinate of the Axon compartment type to the SWC file."
			Abort "Algorithm is stuck at point "+num2str(lastIndex)+". See history window for suggestions."
		endif
		
	while(V_minloc!=firstIndex)

	cHullX[nHullCounter] = {presentX}
	cHullY[nHullCounter] = {presentY}
	nHullCounter += 1
//	print "Hull has "+num2str(nHullCounter)+" points."
//	print "=== Done Finding Convex Hull ==="

End

Function qM_CreateMatrixLimitsTable()

	print "--- Creating Matrix Limits Table ---"
	print "Set the desired limits in X and Y and then recreate the matrix maps."

	if (Exists("qM_MatrixLimits")==0)
		Make/O/N=(4) qM_MatrixLimits
		if (Exists("xMin")==0)
			qM_CreateDefaultMatrixLimits()
		endif
		NVAR xMin,xMax
		NVAR yMin,yMax
		qM_MatrixLimits = {xMin,xMax,yMin,yMax}
	else
		WAVE	qM_MatrixLimits
	endif
	Make/O/T/N=(4) qM_MatrixLimitsLabels
	qM_MatrixLimitsLabels[0] = "xMin"
	qM_MatrixLimitsLabels[1] = "xMax"
	qM_MatrixLimitsLabels[2] = "yMin"
	qM_MatrixLimitsLabels[3] = "yMax"
	
	doWindow/K qM_MatrixLimitsTable
	Edit/K=1/W=(5,53,300,253) qM_MatrixLimitsLabels,qM_MatrixLimits as "Matrix limits"
	doWindow/C qM_MatrixLimitsTable
	ModifyTable title(qM_MatrixLimitsLabels)="Description",title(qM_MatrixLimits)="Value"

End

Function qM_CreateDefaultMatrixLimits()

	Variable/G	xMin = -600		// -605/2
	Variable/G	xMax = 600		//510/2
	Variable	xAbsMax = abs(xMin)>abs(xMax) ? abs(xMin) : abs(xMax)
	xMin = -xAbsMax
	xMax = xAbsMax
	Variable/G	yMin = -580 // -600-150
	Variable/G	yMax = 630 // 700-80
	
//	NVAR		AlignOnL4L5
//	if (AlignOnL4L5)
//		yMin -= 135 // 150
//		yMax -= 135 // 80
//	endif

End

Function CreateMatrices()

	if (Exists("xMin")==0)
		qM_CreateDefaultMatrixLimits()
	endif
	NVAR xMin,xMax
	NVAR yMin,yMax
	
	if (Exists("qM_MatrixLimits"))
		WAVE		qM_MatrixLimits
		xMin = qM_MatrixLimits[0]
		xMax = qM_MatrixLimits[1]
		yMin = qM_MatrixLimits[2]
		yMax = qM_MatrixLimits[3]
	endif
	
	// FIX HERE!
	
	Variable/G	StepSize = 2
	
	Variable	xN = (xMax-xMin)/StepSize+1
	Variable	yN = (yMax-yMin)/StepSize+1
	
	Make/O/N=(xN,yN) AxonMatrix,DendrMatrix,AxonMatrix2,DendrMatrix2
	AxonMatrix = 0
	DendrMatrix = 0
	AxonMatrix2 = 0
	DendrMatrix2 = 0
	SetScale/P x,xMin,StepSize,AxonMatrix,DendrMatrix,AxonMatrix2,DendrMatrix2
	SetScale/P y,yMin,StepSize,AxonMatrix,DendrMatrix,AxonMatrix2,DendrMatrix2

End

Function/C CenterHull(polyX,polyY,MatrixType,xLF,yLF)
	WAVE		polyX
	WAVE		polyY
	String		MatrixType
	WAVE		xLF
	WAVE		yLF
	
	WAVE		theMatrix = $(MatrixType+"Matrix")
	
//	print "CenterHull is using these waves:",NameOfWave(PolyX),NameOfWave(PolyY),NameOfWave(theMatrix),NameOfWave(xLF),NameOfWave(yLF)
	
	WaveStats/Q polyX
	Variable	xMin = V_min
	Variable	xMax = V_max
	
	WaveStats/Q polyY
	Variable	yMin = V_min
	Variable	yMax = V_max
	
	NVAR		StepSize
	
	Variable	xCenter = 0
	Variable	yCenter = 0
	Variable	nPoints = 0
	
	Variable	nAboveL5 = 0
	Variable	nAboveL4 = 0
	NVAR		AreaAboveL5
	NVAR		AreaAboveL4
	NVAR		PercAreaAboveL5
	NVAR		PercAreaAboveL4
	
	Variable	n = 1
	Variable	i,j
	i = 0						// x axis
	do
		j = 0					// y axis
		do
			if (InsidePoly(i+xMin,j+yMin,polyX,polyY))
				xCenter += i+xMin
				yCenter += j+yMin
				theMatrix[(i+xMin - DimOffset(theMatrix, 0))/DimDelta(theMatrix,0)][(j+yMin - DimOffset(theMatrix, 1))/DimDelta(theMatrix,1)] += 1
				if (AboveLine(i+xMin,j+yMin,xLF[0],yLF[0],xLF[1],yLF[1]))		// Also count area above L5
					nAboveL5 += 1
				endif
				if (AboveLine(i+xMin,j+yMin,xLF[6],yLF[6],xLF[7],yLF[7]))		// Also count area above L4
					nAboveL4 += 1
				endif
				nPoints += 1
			endif
			j += StepSize
		while(j+yMin<yMax)
		i += StepSize
	while(i+xMin<xMax)
	xCenter /= nPoints
	yCenter /= nPoints
	PercAreaAboveL5 = nAboveL5/nPoints*100
	PercAreaAboveL4 = nAboveL4/nPoints*100
	AreaAboveL5 = nAboveL5*StepSize^2
	AreaAboveL4 = nAboveL4*StepSize^2
	
//	print "Center hull:",xCenter,yCenter,"\t\tArea above L5:",AreaAboveL5
	
	Variable/C Center = cmplx(xCenter,yCenter)
	
	Return	Center

End

Function testInside(x,y)
	Variable	x
	Variable	y

	WAVE		Axon_cHullX
	WAVE		Axon_cHullY

	print InsidePoly(x,y,Axon_cHullX,Axon_cHullY)

End

Function InsidePoly(x,y,polyX,polyY)
	Variable	x
	Variable	y
	WAVE		polyX
	WAVE		polyY
	
	Variable	n = numpnts(polyX)
	Variable	i
	Variable	side
	Variable	nLeft = 0
	Variable	nRight = 0
	Variable	IsInside = 0
	i = 0
	do
		// From http://local.wasp.uwa.edu.au/~pbourke/geometry/insidepoly/
		// (y - y0) (x1 - x0) - (x - x0) (y1 - y0)
		// Calculate dot product of the two vectors
		side = (y - polyY[i])*(polyX[i+1] - polyX[i]) - (x - polyX[i])*(polyY[i+1] - polyY[i])
		if (side<0)
			nLeft += 1
		else
			nRight += 1
		endif
		i += 1
	while(i<n-1)
	
	if ( (nLeft==0) %| (nRight==0))
		IsInside = 1
	else
		IsInside = 0
	endif
	
	Return IsInside

End

Function ShowReconstruction(Suff,AppendFlag,xOffset,yOffset,reconName,appendAuxInfo)
	String		Suff
	Variable	AppendFlag
	Variable	xOffset
	Variable	yOffset
	String		reconName
	Variable	appendAuxInfo

	Variable	doColorizeMorph = 0
	Variable	fixColorTable = 0
	if (Exists("dendColV"))
		doColorizeMorph = 1
		if (Exists("fixedMinVal"))
			NVAR	fixedMinVal
			NVAR	fixedMaxVal
			fixColorTable = 1
		endif
	endif

	Variable	showProper = 1					// Show proper reconstruction always -- keep old code for future reference only

	Variable	xPos = 21
	Variable	yPos = 76
	Variable	Width = 250
	Variable	Height = 350
	
	if (doColorizeMorph)
		Width *= 2.5
	endif
	
	Variable	invertCol = 1
	
	Variable	Lthick = 0.25
	
	NVAR		LF_Exists
	NVAR		Extent_Exists
	
	SVAR		fName

	if (AppendFlag)
		DoWindow/F ReconPlot
//		RemoveFromGraph/Z yLimits
	else
		DoWindow/K ReconPlot
		Display /W=(xPos,yPos,xPos+Width,yPos+Height) as fName
		DoWindow/C ReconPlot
		if (showProper)
			AppendToGraph yLimits vs xLimits
			ModifyGraph mode=2
		endif
	endif

	if (showProper)
		// Show proper reconstruction	
		SetDrawLayer UserFront
//		print "Group"+Suff
		SetDrawEnv gstart,gname= $("Group"+Suff)
		// Draw axon
		if (doColorizeMorph)
			Variable	graySc = 0.7
			SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (65535*graySc,65535*graySc,65535*graySc),linethick=(Lthick),linefgc= (65535*graySc,65535*graySc,65535*graySc)
			DrawPoly xOffset,yOffset,1,1,$("properX_axon"+Suff),$("properY_axon"+Suff)
		else
			SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (65535,50000,3600),linethick=(Lthick),linefgc= (65535,50000,3600)
			DrawPoly xOffset,yOffset,1,1,$("properX_axon"+Suff),$("properY_axon"+Suff)
		endif
		// Draw dendrite
		if (doColorizeMorph)
			ColorTab2Wave Rainbow
			WAVE		M_colors
			Variable	nColors = DimSize(M_colors,0)
			WAVE		morphColW
			Variable	n = numpnts(morphColW)
			Variable	maxVal
			Variable	minVal
			if (fixColorTable)
				maxVal = fixedMaxVal
				minVal = fixedMinVal
			else
				WaveStats/Q morphColW
				maxVal = V_max
				minVal = V_min
			endif
			ColorScale ctab={minVal,maxVal,Rainbow,invertCol}, "voltage (mV)"
			ColorScale/C/N=text0/A=RC/E minor=1
			Variable	colVal
			Variable	i
			i = 0
			do
				if (invertCol)
					colVal = Floor((maxVal-morphColW[i])/(maxVal-minVal)*nColors)
				else
					colVal = Floor((morphColW[i]-minVal)/(maxVal-minVal)*nColors)
				endif
				WAVE	xW = $("colMorphSegX_"+JT_num2digstr(4,i))
				WAVE	yW = $("colMorphSegY_"+JT_num2digstr(4,i))
				SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (M_colors[colVal][0],M_colors[colVal][1],M_colors[colVal][2]),linethick=(Lthick),linefgc= (M_colors[colVal][0],M_colors[colVal][1],M_colors[colVal][2])
//				SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (65535,0,65535),linethick= 1.00,linefgc= (65535,0,65535)
				DrawPoly xOffset+xW[0],yOffset+yW[0],1,1,$("colMorphSegX_"+JT_num2digstr(4,i)),$("colMorphSegY_"+JT_num2digstr(4,i))
				i += 1
			while(i<n)
		else
			SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (65535,0,65535),linethick=(Lthick),linefgc= (65535,0,65535)
			DrawPoly xOffset,yOffset+1,1,1,$("properX_dend"+Suff),$("properY_dend"+Suff)
		endif
		SetDrawEnv gstop
		if (appendAuxInfo)
			if (StrLen(reconName)>0)
				SetDrawEnv xcoord= bottom,textxjust=1,fsize=8
				DrawText xOffset,yOffset,reconName
			endif
		endif
	else
		AppendToGraph $("drawY"+Suff) vs $("drawX"+Suff)
		ModifyGraph mode($("drawY"+Suff))=4
		ModifyGraph marker($("drawY"+Suff))=19
		ModifyGraph mrkThick($("drawY"+Suff))=1
		ModifyGraph zmrkSize($("drawY"+Suff))={$("drawD"+Suff),*,*,0.24,14.65}
		ModifyGraph zColor($("drawY"+Suff))={$("drawCT"+Suff),*,*,cindexRGB,0,myColors}
	endif

	if (appendAuxInfo)
		AppendToGraph $("yCenters"+Suff) vs $("xCenters"+Suff)
		ModifyGraph offset($("yCenters"+Suff))={xOffset,yOffset}
	
		AppendToGraph $("Axon_cHullY"+Suff) vs $("Axon_cHullX"+Suff)
		ModifyGraph offset($("Axon_cHullY"+Suff))={xOffset,yOffset}
	
		AppendToGraph $("Dendr_cHullY"+Suff) vs $("Dendr_cHullX"+Suff)
		ModifyGraph offset($("Dendr_cHullY"+Suff))={xOffset,yOffset}
	
		ModifyGraph mode($("yCenters"+Suff))=3
		ModifyGraph marker($("yCenters"+Suff))=18
		ModifyGraph lStyle($("Dendr_cHullY"+Suff))=1
		ModifyGraph rgb($("yCenters"+Suff))=(0,0,0),rgb($("Axon_cHullY"+Suff))=(0,0,0),rgb($("Dendr_cHullY"+Suff))=(0,0,0)
		ModifyGraph msize($("yCenters"+Suff))=5
		ModifyGraph textMarker($("yCenters"+Suff))={$("CenterTagsT"+Suff),"default",1,0,5,0.00,0.00}
	
		if (LF_Exists)
			if (Exists("yCoord2LF"+Suff))
				AppendToGraph $("yCoord2LF"+Suff) vs $("xCoord2LF"+Suff)
				ModifyGraph offset($("yCoord2LF"+Suff))={xOffset,yOffset}
				ModifyGraph mode($("yCoord2LF"+Suff))=4
				ModifyGraph lStyle($("yCoord2LF"+Suff))=11
				ModifyGraph rgb($("yCoord2LF"+Suff))=(65535/2,65535/2,65535/2)
				ModifyGraph marker($("yCoord2LF"+Suff))=8,opaque($("yCoord2LF"+Suff))=1
			endif
		endif
			
		if (Extent_Exists)
			if (Exists("yCoord2Ext"+Suff))
				AppendToGraph $("yCoord2Ext"+Suff) vs $("xCoord2Ext"+Suff)
				ModifyGraph offset($("yCoord2Ext"+Suff))={xOffset,yOffset}
				ModifyGraph mode($("yCoord2Ext"+Suff))=0
				ModifyGraph lStyle($("yCoord2Ext"+Suff))=2
				ModifyGraph rgb($("yCoord2Ext"+Suff))=(32768,40777,65535)
			endif
		endif
	endif
	
	if (doColorizeMorph)
		ModifyGraph tick=1
		ModifyGraph manTick={0,100,0,0},manMinor={0,50}
		ModifyGraph height={Plan,1,left,bottom}
	else
		ModifyGraph margin(left)=24,margin(right)=8
		ModifyGraph standoff=0
		ModifyGraph tick=1
		ModifyGraph manTick={0,200,0,0},manMinor={0,50}
	endif
	
	JT_AddResizeButton()

End

Function MakeHullGraph()

	Variable	n = 20
	Variable	i
	String		currNameY,currNameX

	DoWindow/K HullGraph1
	Display/W=(35,44,404,569) 
	nw("HullGraph1")
	
	i = 0
	do
		currNameY = "Axon_cHullY_Type_1_"+num2str(i+1)
		currNameX = "Axon_cHullX_Type_1_"+num2str(i+1)
		if (Exists(currNameY))
			AppendToGraph $currNameY vs $currNameX
		else
			i = Inf
		endif
		i += 1
	while(i<n)

	i = 0
	do
		currNameY = "Axon_cHullY_Type_2_"+num2str(i+1)
		currNameX = "Axon_cHullX_Type_2_"+num2str(i+1)
		if (Exists(currNameY))
			AppendToGraph $currNameY vs $currNameX
			ModifyGraph rgb($currNameY)=(0,0,65535)
		else
			i = Inf
		endif
		i += 1
	while(i<n)

	DoWindow/K HullGraph2
	Display/W=(35+450,44,404+450,569) 
	nw("HullGraph2")
	
	i = 0
	do
		currNameY = "Dendr_cHullY_Type_1_"+num2str(i+1)
		currNameX = "Dendr_cHullX_Type_1_"+num2str(i+1)
		if (Exists(currNameY))
			AppendToGraph $currNameY vs $currNameX
		else
			i = Inf
		endif
		i += 1
	while(i<n)

	i = 0
	do
		currNameY = "Dendr_cHullY_Type_2_"+num2str(i+1)
		currNameX = "Dendr_cHullX_Type_2_"+num2str(i+1)
		if (Exists(currNameY))
			AppendToGraph $currNameY vs $currNameX
			ModifyGraph rgb($currNameY)=(0,0,65535)
		else
			i = Inf
		endif
		i += 1
	while(i<n)

End

// Legacy proc -- no longer needed?

Function ShowProperRecon()
	DoWindow/K ProperReconGraph
	Display /W=(106,110,553,545) yLimits vs xLimits as "Proper reconstruction"
	DoWindow/C ProperReconGraph
	ModifyGraph mode=2
	ModifyGraph width={Plan,1,bottom,left},height=0
	ShowTools/A
	SetDrawLayer UserFront
	// Draw axon
	SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (65535,50000,3600),linethick= 1.00,linefgc= (65535,50000,3600)
	DrawPoly 0,0,1,1,properX_axon,properY_axon
	// Draw dendrite
	SetDrawEnv xcoord= bottom,ycoord= left,fillfgc= (65535,0,65535),linethick= 1.00,linefgc= (65535,0,65535)
	DrawPoly 0,0,1,1,properX_dend,properY_dend
End

Function appendSegment(x1,y1,d1,x2,y2,d2,xW,yW)
	Variable	x1,y1,d1
	Variable	x2,y2,d2
	WAVE		xW,yW
	
	if (numpnts(xW) != numpnts(yW))
		Print "Strange error in {appendSeg}: x and y waves have different number of coordinates."
		Abort "Strange error in {appendSeg}: x and y waves have different number of coordinates."
	endif
	
	// Leave gap between this and previous segment
	xW[numpnts(xW)] = {NaN}
	yW[numpnts(yW)] = {NaN}
	
	// Calculate corners of segment
	Variable/C v1 = calcCorner(x2-x1,y2-y1,d1/2)
	Variable/C v2 = calcCorner(x2-x1,y2-y1,-d1/2)
	Variable/C v3 = calcCorner(x2-x1,y2-y1,-d2/2)
	Variable/C v4 = calcCorner(x2-x1,y2-y1,d2/2)
	
	// Add next segment
	xW[numpnts(xW)] = {x1+real(v1)}
	yW[numpnts(yW)] = {y1+imag(v1)}
	xW[numpnts(xW)] = {x1+real(v2)}
	yW[numpnts(yW)] = {y1+imag(v2)}
	xW[numpnts(xW)] = {x2+real(v3)}
	yW[numpnts(yW)] = {y2+imag(v3)}
	xW[numpnts(xW)] = {x2+real(v4)}
	yW[numpnts(yW)] = {y2+imag(v4)}
	xW[numpnts(xW)] = {x1+real(v1)}
	yW[numpnts(yW)] = {y1+imag(v1)}
	
End

Function newSegment(x1,y1,d1,x2,y2,d2,suffixNumber)
	Variable	x1,y1,d1
	Variable	x2,y2,d2
	Variable	suffixNumber
	
	Make/O/N=(0) $("colMorphSegX_"+JT_num2digstr(4,suffixNumber))
	Make/O/N=(0) $("colMorphSegY_"+JT_num2digstr(4,suffixNumber))
	
	WAVE	xW = $("colMorphSegX_"+JT_num2digstr(4,suffixNumber))
	WAVE	yW = $("colMorphSegY_"+JT_num2digstr(4,suffixNumber))
	
	// Calculate corners of segment
	Variable/C v1 = calcCorner(x2-x1,y2-y1,d1/2)
	Variable/C v2 = calcCorner(x2-x1,y2-y1,-d1/2)
	Variable/C v3 = calcCorner(x2-x1,y2-y1,-d2/2)
	Variable/C v4 = calcCorner(x2-x1,y2-y1,d2/2)
	
	// Add next segment
	xW[numpnts(xW)] = {x1+real(v1)}
	yW[numpnts(yW)] = {y1+imag(v1)}
	xW[numpnts(xW)] = {x1+real(v2)}
	yW[numpnts(yW)] = {y1+imag(v2)}
	xW[numpnts(xW)] = {x2+real(v3)}
	yW[numpnts(yW)] = {y2+imag(v3)}
	xW[numpnts(xW)] = {x2+real(v4)}
	yW[numpnts(yW)] = {y2+imag(v4)}
	xW[numpnts(xW)] = {x1+real(v1)}
	yW[numpnts(yW)] = {y1+imag(v1)}
	
End

Function/C calcCorner(x1,y1,r1)
	Variable	x1,y1,r1
	
	Variable	x2,y2
	
	Variable	signVar = sign(r1)
	
	Variable	signVar1 = -sign(y1)
	Variable	signVar2 = -sign(x1)

	// x1*x2 + y1*y2 = 0				dot product is zero
	// sqrt(x2^2 + y2^2) = r1			length is r1
	// =>
	// x2 = ±sqrt(r1^2*y1^2/(x1^2+y1^2))
	// y2 = ±sqrt(r1^2*x1^2/(x1^2+y1^2))
	
	x2 = -signVar1*sqrt(r1^2*y1^2/(x1^2+y1^2))
	y2 = signVar2*sqrt(r1^2*x1^2/(x1^2+y1^2))
	
	x2 *= signVar
	y2 *= signVar
	
	Return cmplx(x2,y2)
	
End


