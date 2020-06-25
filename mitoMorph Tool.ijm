// Manual cell outliner and mitochondria analysis tools
//
// Author: Giovanni Cardone - MPI Biochemistry
//
// This is a set of tools to quickly outline cells, segment mitochondria,
// quantify their morphology, and save the results.
// It was developed specifically for the research published in https://doi.org/10.1093/nar/gkz1128
// Dependencies:
// mask2convex_hull.groovy script (should be provided with this script)
// ImageScience update site activated
//
/////////////////// Global variables ///////////////////
var MitochondriaResultsTable = "Mitochondria statistics";
var MitochondriaResultsFile = "Mitochondria_statistics.txt";
var MitochondriaSummaryTable = "Mitochondria summary statistics";
var MitochondriaSummaryFile = "Mitochondria_summary_statistics.txt";
var MitochondriaLengthTable = "Mitochondria length statistics";
var MitochondriaLengthFile = "Mitochondria_length_statistics.txt";

var mitochondriaLegendName = "Mitochondria legend";


/////////////////// Global input parameters ///////////////////
var subDirImagesName = "Images";
var subDirCellsName = "Cells";
var rootDirName = "";
var rootImgName = "";

var displayJunk = false;
var aggressive =  false;

// minimum area to accept objects as mitochondria (squared micrometers)
var minAbsArea = 0.36;

// minimum area to accept objects with low solidity (squared micrometers)
var minCondArea = 0.8;

// solidity threshold
var maxJunkSolidity = 0.8;

// minimum skeletonized length of filamentous mitochondria (micrometers)
var thresholdNetworkLength = 11;

// combined constraints on length (micrometers), width (micrometers)
// and solidity of filaments
var minNetworkLength = 5;
var minNetworkLinearExtension = 1.5;
var maxNetworkCompactness = 0.6;

// combined constraints on area (squared micrometers), skeletonized length
// (micrometers), circularity and solidity of puncta
var maxPunctaArea = 1.2;
var maxPunctaLinearExtension = 1.2;
var minPunctaCircularity = 0.5;
var maxPunctaAspectRatio = 3;

// combined constraints on area (squared micrometers), range of allowed
// skeletonized lengths (micrometers), circularity, aspect ratio and solidity
// of swollen mitochondria
var minSwollenArea = 1.2;
var minSwollenLinearExtension = 1.1;
var maxSwollenLength = 5;
var minSwollenCircularity = 0.5;
var maxSwollenAspectRatio = 4;
var minSwollenCompactness = 0.6;


/////////////////// Macros ///////////////////
macro "Unused Tool-1 - " {}  // leave slot unused


// Parameter settings
macro "Settings Action Tool - D3eD4eD5eD6bD6cD6dD7aD89D98Da7Db6Dc6Dd6De4De5D2aD5dDa2Dd5D59D68D69D77D78D86D87D96D1aD1bD1cD29D2bD39D49D4bD4cD4dD58D67D76D85D92D93D94Da1Db1Db2Db4Dc1Dc4Dd4De3D5aD6aD79D88D95D97Da5Da6D19D91D4aD5bDa4Db5D3aD5cDa3Dc5" {
      um = getInfo("micrometer.abbreviation");
      Dialog.create("mitoMorph settings");
      Dialog.addMessage("--- Saving preferences: subdirectories ---");
      Dialog.addString("Images with cell outlines:", subDirImagesName);
      Dialog.addString("Single cells with mitochondria highlighted:", subDirCellsName);
      Dialog.addMessage("--- Display preferences ---");
      Dialog.addCheckbox("Display rejected objects in the cartoon", displayJunk);
      Dialog.addMessage("--- Segmentation criteria ---");
      Dialog.addCheckbox("Enhance weak intensities", aggressive);
      Dialog.addMessage("--- Classification criteria ---");
      Dialog.addMessage("- Exclusion");
      Dialog.addNumber("1: Objects with area smaller than ("+um+"^2):", minAbsArea);
      Dialog.addNumber("2: Objects with area smaller than ("+um+"^2):", minCondArea);
      Dialog.addNumber("   and solidity less than:", maxJunkSolidity);
      Dialog.addMessage("- Filaments network");
      Dialog.addNumber("1: Objects with total length longer than ("+um+"):", thresholdNetworkLength);
      Dialog.addNumber("2: Objects with total length longer than ("+um+"):", minNetworkLength);
      Dialog.addNumber("   and minimum linear extension larger than ("+um+"):", minNetworkLinearExtension);
      Dialog.addNumber("   and solidity less than:", maxNetworkCompactness);
      Dialog.addMessage("- Puncta");
      Dialog.addNumber("1: Objects with area smaller than ("+um+"^2):", maxPunctaArea);
      Dialog.addNumber("   and minimum linear extension less than ("+um+"):", maxPunctaLinearExtension);
      Dialog.addNumber("   and circularity larger than:", minPunctaCircularity);
      Dialog.addNumber("   and aspect ratio smaller than:", maxPunctaAspectRatio);
      Dialog.addMessage("- Swollen");
      Dialog.addNumber("1: Objects with area larger than ("+um+"^2):", minSwollenArea);
      Dialog.addNumber("   and minimum linear extension larger than ("+um+"):", minSwollenLinearExtension);
      Dialog.addNumber("   and total length less than ("+um+"):", maxSwollenLength);
      Dialog.addNumber("   and circularity larger than:", minSwollenCircularity);
      Dialog.addNumber("   and aspect ratio smaller than:", maxSwollenAspectRatio);
      Dialog.addNumber("   and solidity larger than:", minSwollenCompactness);
      Dialog.addMessage("- Fragmented filaments");
      Dialog.addMessage("  All the objects not satisfying any of the above criteria");
      Dialog.show();
      subDirImagesName = Dialog.getString();
      subDirCellsName = Dialog.getString();

      displayJunk = Dialog.getCheckbox();
      aggressive = Dialog.getCheckbox();

      minAbsArea = Dialog.getNumber();
      minCondArea = Dialog.getNumber();
      maxJunkSolidity = Dialog.getNumber();

      thresholdNetworkLength = Dialog.getNumber();
      minNetworkLength = Dialog.getNumber();
      minNetworkLinearExtension = Dialog.getNumber();
      maxNetworkCompactness = Dialog.getNumber();

      maxPunctaArea = Dialog.getNumber();
      maxPunctaLinearExtension = Dialog.getNumber();
      minPunctaCircularity = Dialog.getNumber();
      maxPunctaAspectRatio = Dialog.getNumber();

      minSwollenArea = Dialog.getNumber();
      minSwollenLinearExtension = Dialog.getNumber();
      maxSwollenLength = Dialog.getNumber();
      minSwollenCircularity = Dialog.getNumber();
      maxSwollenAspectRatio = Dialog.getNumber();
      minSwollenCompactness = Dialog.getNumber();
}


// clean up ROI Manager and load overlays in image as cell outlines
macro "Load cells from image Action Tool - C000D0aD0bD0cD0dD0eD0fD16D1aD1bD1cD1dD1eD1fD24D26D2eD2fD34D35D3eD3fD49D4eD4fD59D5aD5eD5fD65D66D67D68D69D6aD6bD6eD6fD75D76D77D78D79D7aD7bD7cD7eD7fD83D85D86D87D88D89D8aD8bD8eD8fD91D93D99D9aD9eD9fDa1Da2Da9DaeDafDb7DbeDbfDc5Dc7DceDcfDd5Dd6DdeDdfDeaDebDecDedDeeDefDfaDfbDfcDfdDfeDffC000C111C222C333C444C555C666C777C888C999CaaaCbbbCcccCdddCeeeCfff"{
  roiManager("show none");
  roiManager("reset");
  if (nImages>0) {
    run("Select None");
    if (Overlay.size > 0) {
      Overlays2ROIs();
      renameRois();
    }
  }
}


// add ROI traced around the cell to overlays
macro "Add cell [F5] Action Tool - C000D1bD1cD1dD2aD2bD2cD2dD2eD39D3eD44D48D49D4eD52D53D54D55D56D57D58D5eD61D62D6eD6fD71D76D7eD80D81D86D8eD90D91D94D95D96D97D98D9eDa1Da6DadDb1Db6DbbDbcDbdDc1Dc2DcaDcbDccDd2Dd3Dd8Dd9DdaDe3De4De5De6De7De8C000D3aD45Da0DaeC000C111D5fD9dC111C222D29D7fDacDd4C222D43C222Dc9Dd7C222C333D70C333D46D47C333D3dC333C444De9C444Db2C444D51C444D38DdbC555Dd6C555D3bDd5C555D4fDc3C555C666Db0C666D8dC666D72D8fC666D4dC666D67C666C777D59C777Dd1C777D63C777D5dD7dC777D42C777D66C777D6dC777C888D1eC888Da2C888De2C888C999D3fC999DbaDf5C999D1aDf6C999D4aC999CaaaD60CaaaDc0CaaaD9fCaaaD82CaaaD92CaaaDf4CaaaD68Df7CbbbDc8CbbbDbeCbbbDcdCbbbD65CbbbCcccD2fCcccDeaCcccD3cCcccCdddDf8CdddD64CdddDf3CdddD0cCdddCeeeDafCeeeD0dDabCeeeD9cCeeeD28CeeeDdcCeeeD19CfffD0bD50CfffD34D69CfffDe1CfffD35D41CfffDb9Dd0Df9CfffD1fD37CfffD33Dc4CfffD0eD36D5aDebCfffDb3Dc7Df2CfffD4bDaaDce"{
    addOutline();
}
// F key shortcut
macro "Add cell [F5]" {
    addOutline();
}


// remove selected ROI from overlays
macro "Delete cell [F9] Action Tool - C000D1bD1cD1dD2aD2bD2cD2dD2eD39D3eD44D48D49D4eD52D53D54D55D56D57D58D5eD61D62D6eD6fD71D76D7eD80D81D86D8eD90D91D96D9eDa1Da6DadDb1Db6DbbDbcDbdDc1Dc2DcaDcbDccDd2Dd3Dd8Dd9DdaDe3De4De5De6De7De8C000D3aD45Da0DaeC000C111D5fD9dC111C222D29D7fDacDd4C222D43C222Dc9Dd7C222C333D70C333D46D47C333D3dC333C444De9C444Db2C444D51C444D38DdbC555Dd6C555D3bDd5C555D4fDc3C555C666Db0C666D8dC666D72D8fC666D4dC666D67C666C777D59C777Dd1C777D63C777D5dD7dC777D42C777D66C777D6dC777C888D1eC888Da2C888De2C888C999D3fC999DbaDf5C999D1aDf6C999D4aC999CaaaD60CaaaDc0CaaaD9fCaaaD82CaaaD92CaaaDf4CaaaD68Df7CbbbDc8CbbbDbeCbbbDcdCbbbD65CbbbCcccD2fCcccDeaCcccD3cCcccCdddDf8CdddD64CdddDf3CdddD0cCdddCeeeDafCeeeD0dDabCeeeD9cCeeeD28CeeeDdcCeeeD19CfffD0bD50CfffD34D69CfffDe1CfffD35D41CfffDb9Dd0Df9CfffD1fD37CfffD33Dc4CfffD0eD36D5aDebCfffDb3Dc7Df2CfffD4bDaaDce"{
    deleteOutline();
}
// F key shortcut
macro "Delete cell [F9]" {
    deleteOutline();
}


// segment and quantify mitochondria from selected cell ROI
macro "Segment mitochondria from selected cell [F6] Action Tool - C0f0D21D22D23D8cD9cD9dDadCfffD00D01D02D03D04D05D06D07D08D09D0aD0bD0cD0dD0eD0fD10D11D12D13D14D15D16D17D18D19D1aD1bD1cD1eD1fD20D24D25D26D27D29D2aD2bD2cD2dD2eD2fD30D31D32D33D34D35D39D3dD3eD3fD40D41D42D47D48D49D4dD4eD4fD50D51D54D55D56D57D58D59D5dD5eD5fD60D61D63D64D65D66D67D68D69D6aD6bD6cD6dD6eD6fD70D71D72D73D74D75D77D78D79D7aD7bD7cD7dD7eD7fD80D81D82D83D84D85D86D87D88D89D8aD8bD8dD8eD8fD90D91D92D93D99D9aD9bD9eD9fDa0Da1Da2Da3Da4Da5Da6Da7DaaDabDacDaeDafDb0Db1Db2Db3Db4Db5Db6Db7Db8DbbDbcDbdDbeDbfDc0Dc1Dc3Dc4Dc5Dc6Dc7Dc8Dc9DccDcdDceDcfDd0Dd1Dd2Dd3Dd4Dd5Dd7Dd8Dd9DdaDddDdeDdfDe0De1De2De3De4De5De6De7De8De9DeaDebDecDedDeeDefDf0Df1Df2Df3Df4Df5Df6Df7Df8Df9DfaDfbDfcDfdDfeDffCf0fD28D36D37D38D43D44D45D46D52D53D62D94D95D96D97D98Da8Da9Db9DbaDcaDcbDdbDdcC00fD3aD3bD3cD4aD4bD4cD5aD5bD5cCf70D1dD76Dc2Dd6"{
    mitoClassesFractions = checkAndSegment();
}
// F key shortcut
macro "Segment mitochondria [F6]" {
    mitoClassesFractions = checkAndSegment();
}


// segment and quantify mitochondria from all cell outlined in the image
macro "Segment mitochondria from all cells in the image [F7] Action Tool - C000D62D63D64D65D66D67D68D69D6aD6bD6cD6dD72D73D74D75D76D77D78D79D7aD7bD7cD7dD82D83D84D85D86D87D88D89D8aD8bD8cD8dCfffD00D01D02D03D04D05D06D07D08D09D0aD0bD0cD0dD0eD0fD10D11D12D13D14D15D16D17D18D19D1aD1bD1cD1eD1fD20D24D25D26D27D29D2aD2bD2cD2dD2eD2fD30D31D32D33D34D35D39D3dD3eD3fD40D41D42D47D48D49D4dD4eD4fD50D51D54D55D56D57D58D59D5dD5eD5fD60D61D6eD6fD70D71D7eD7fD80D81D8eD8fD90D91D92D93D99D9aD9bD9eD9fDa0Da1Da2Da3Da4Da5Da6Da7DaaDabDacDaeDafDb0Db1Db2Db3Db4Db5Db6Db7Db8DbbDbcDbdDbeDbfDc0Dc1Dc3Dc4Dc5Dc6Dc7Dc8Dc9DccDcdDceDcfDd0Dd1Dd2Dd3Dd4Dd5Dd7Dd8Dd9DdaDddDdeDdfDe0De1De2De3De4De5De6De7De8De9DeaDebDecDedDeeDefDf0Df1Df2Df3Df4Df5Df6Df7Df8Df9DfaDfbDfcDfdDfeDffC0f0D21D22D23D9cD9dDadCf70D1dDc2Dd6Cf0fD28D36D37D38D43D44D45D46D52D53D94D95D96D97D98Da8Da9Db9DbaDcaDcbDdbDdcC00fD3aD3bD3cD4aD4bD4cD5aD5bD5c"{
    segmentMitochondriaFromAllCells();
}
// F key shortcut
macro "Segment mitochondria from all cells [F7]" {
    segmentMitochondriaFromAllCells();
}


// segment and quantify mitochondria - batch mode on input directory
macro "Segment mitochondria / batch mode [F8] Action Tool - C000D53D54D55D56D57D58D59D5aD5bD63D64D65D66D67D68D69D6aD6bD73D74D77D7aD7bD83D85D86D87D88D89D8bD94D9aCfffD00D01D02D03D04D05D06D07D08D09D0aD0bD0cD0dD0eD0fD10D11D12D13D14D15D16D17D18D19D1aD1bD1cD1eD1fD20D24D25D26D27D29D2aD2bD2cD2dD2eD2fD30D31D32D33D34D35D39D3dD3eD3fD40D41D42D47D48D49D4dD4eD4fD50D51D5dD5eD5fD60D61D6cD6dD6eD6fD70D71D72D7cD7dD7eD7fD80D81D82D8dD8eD8fD90D91D92D93D9bD9eD9fDa0Da1Da2Da3Da4Da5Da6Da7DaaDabDacDaeDafDb0Db1Db2Db3Db4Db5Db6Db7Db8DbbDbcDbdDbeDbfDc0Dc1Dc3Dc4Dc5Dc6Dc7Dc8Dc9DccDcdDceDcfDd0Dd1Dd2Dd3Dd4Dd5Dd7Dd8Dd9DdaDddDdeDdfDe0De1De2De3De4De5De6De7De8De9DeaDebDecDedDeeDefDf0Df1Df2Df3Df4Df5Df6Df7Df8Df9DfaDfbDfcDfdDfeDffC111D8aC100D95D99Cf0fD28D36D37D38D43D44D45D46D52D62D97Da8Da9Db9DbaDcaDcbDdbDdcC00fD3aD3bD3cD4aD4bD4cD5cCe60D76C0f0D21D22D23D8cD9cD9dDadC200D96D98CeeeD75Cf70D1dDc2Dd6C222D84CeeeD78D79"{
    segmentMitochondriaBatch();
}
// F key shortcut
macro "Segment mitochondria / batch mode [F8]" {
    segmentMitochondriaBatch();
}


// save the current image to a user defined directory
macro "Save Action Tool - C000C111C222C333C444C555Dc8C555Db8C555C666Da8C666D88D98C666D78C666D58D68C666D48C666D38C666DfbC666DebDfaC666DdbC666Df9C777D28C777DcbC777Df8C777DbbC777Df7C777Dd8C777DabC777Df6C777D9bC777C888Df5C888D8bC888D7bDf4C888D6bC888D5bDe3C888C999D4bC999De2C999D3bC999Dc9C999Db9C999D2bC999D99Da9Dd1C999Dc7C999D89Db7C999CaaaD1bCaaaD79Da7Dc1CaaaD69Dd9CaaaD97CaaaD0bD59CaaaD87Db1De4CaaaD49D77CaaaD39D67Dd7CaaaD0aDa1CaaaD57CaaaD47CaaaD37CaaaD09D91CaaaCbbbDc6Dd2CbbbD29Db6CbbbD08D81CbbbDa6Dd6CbbbD71D96CbbbD07D27CbbbD86CbbbD76CbbbD61CbbbD06D66CbbbD51D56CbbbD05CcccD46CcccD36D41CcccDb3De6CcccD04D13CcccD31CcccD84CcccD12D21D26D74D94DdaDe9CcccDcaCcccDbaDe8CcccD9aDa4DaaCcccD64CcccD7aD8aCcccD14D6aCcccDe7CdddD5aDb4De5CdddD22D4aDc3CdddD3aD54CdddD2aDd3CdddD19CdddD44CdddD18CdddD16CdddD33Dc5CdddDb5CdddD17D95Da5Dc4CdddD34D85CdddD65D75Da3CeeeD45D55D73D83D93Dd5CeeeD35D63CeeeD43D53DeaCeeeD15D23CeeeD25CeeeDd4CeeeD1aCeeeD24D92Da2Db2CeeeD42D52D62D72D82CeeeCfffDc2CfffD32CfffD00D01D02D03D0cD0dD0eD0fD10D11D1cD1dD1eD1fD20D2cD2dD2eD2fD30D3cD3dD3eD3fD40D4cD4dD4eD4fD50D5cD5dD5eD5fD60D6cD6dD6eD6fD70D7cD7dD7eD7fD80D8cD8dD8eD8fD90D9cD9dD9eD9fDa0DacDadDaeDafDb0DbcDbdDbeDbfDc0DccDcdDceDcfDd0DdcDddDdeDdfDe0De1DecDedDeeDefDf0Df1Df2Df3DfcDfdDfeDff" {
    saveEverything(true,true);
}


macro "Help F keys Action Tool - C000D54D73D78D7bD7cD87D94D95D96Da5C000D83C000D84D88D97C000C111D64C111C222D63C222Da6C222C333D74D8bD8cC333Da4C333C444D93C444C555D86C555D53C666D79C666D77C666D6bD6cC666C777C888D89C888D68D85C999D7aC999CaaaD69CaaaD55CaaaD8aCaaaCbbbCcccD6aD98CcccDa7CcccCdddCeeeDa3CeeeCfffD6eD7eCfff"{
    showMessage("--- Keyboard shortcuts ---\n    F5: add cell outline to list\n    F6: segment mitochondria from selected cell\n    F7: segment mitochondria from all cells in the image\n    F8: segment mitochondria from images previously screened (batch mode)\n    F9: delete selected cell from list");
}

/////////////////// Functions ///////////////////

function saveEverything(verbose,includeOriginalImages) {
  n = nImages;
  if (n < 1) {
    showMessage("no image open!\n");
    exit();
  }
  refImgID = getImageID();
  setBatchMode(true);

  nCells = 0;
  nInputs = 0;
  // generate coupled lists of dirnames/filenames to determine the root
  // directory of each cell
  dirList = newArray();
  namesList = newArray();
  for (im=1; im<=nImages; im++){
    selectImage(im);
    imgID = getImageID();
    title = getTitle();

    if (title != mitochondriaLegendName) {
      dirname = getInfo("image.directory");
      if (dirname!="") {
        dirList = Array.concat(dirList,dirname);
        namesList = Array.concat(namesList,title+"_");
      }
    }
  }

  for (im=1; im<=nImages; im++){
    skipThis = false;
    selectImage(im);
    imgID = getImageID();

    title = getTitle();

    if (title != mitochondriaLegendName) {
      dirname = getInfo("image.directory");

      // determine which kind of image is
      addSubDirImagesName = true;
      if (dirname=="") {
        isOriginalImage = false;
      } else {
        isOriginalImage = true;
        if (nSlices==1) {
          // don't write to a subdirectory, if the image is already in it
          dirPieces = split(dirname,File.separator);
          if(dirPieces.length>1) {
            lastPiece = dirPieces[dirPieces.length-1];
            if (lastPiece==subDirImagesName) {
              addSubDirImagesName = false;
            }
          }
        }
      }


      // generate the name of output file
      if (isOriginalImage) {
        if (includeOriginalImages && Overlay.size>0){
          pieces = split(title,".");
          if(pieces.length>1) {
            lastPiece = pieces[pieces.length-1];
            if (lengthOf(lastPiece)<=4) {
              filename = pieces[0];
              for (i=1; i<pieces.length-1; i++) {
                filename += "."+pieces[i];
              }
              filename += ".tif";
            } else {
              filename = title;
            }
          } else {
            filename = title;
          }
          outputDirectory = dirname+File.separator;
          if (addSubDirImagesName) {
              outputDirectory += subDirImagesName+File.separator;
          }
          nInputs += 1;
        } else {
          skipThis = true;
        }
      } else {
        // if it's a cell, then just append extension
        filename = title+".tif";
        dirname = "";
        for (il=0; il<dirList.length; il++) {
          if (startsWith(title,namesList[il])) {
            dirname = dirList[il];
          }
        }
        if (dirname == "") {
          showMessage("WARNING", title+" not saved! No reference directory found.");
          skipThis = true;
        } else {
          nCells += 1;
        }
        outputDirectory = dirname+File.separator+subDirCellsName+File.separator;
      }

      if (!skipThis) {
        if (!File.isDirectory(outputDirectory) ) {
          File.makeDirectory(outputDirectory);
        }

        outfile = outputDirectory + filename;
        // make a copy of the image to avoid that the new output directory
        // is stored into the original image info
        roiManager("Show None");
        run("Select None");
        run("Show Overlay");

        setOption("Changes", false);

        run("Duplicate...", "use");

        saveAs("Tiff", outfile);
        close();
      }
    }
  }

  selectImage(refImgID);
  setBatchMode(false);
  if (verbose == true) {
    notifyMessage = "";
    if (nInputs>0) {
      notifyMessage += "Saved "+nInputs+" images\n";
    }
    if (nCells>0){
      notifyMessage += "Saved "+nCells+" cells\n";
    }
    if (nInputs == 0 && nCells ==0) {
      notifyMessage = "no Images saved";
    }
    showMessage("Done!", notifyMessage);
  }
}


// add ROI traced around the cell to overlays
function addOutline(){
    type = selectionType();
    if (type>=0) {
      title = getTitle();
      if (isWorkingOnNewImage(title)){
        roiManager("reset");
      }
      rootImgName = title;
      col = randomColor();
      Overlay.addSelection(col);
      Overlays2ROIs();
      renameRois();
    }
}


function deleteOutline(){
  cellID = roiManager("index");
  if (cellID<0) {
      showMessage("no cell selected!\n");
      exit();
  }
  roiManager("Select",cellID);
  roiManager("delete");
  renameRois();
  run("Remove Overlay");
  ROIs2Overlays(false,false);
}


function segmentMitochondria () {
  imgID = getImageID();
  imgTitle = getTitle();
  suffix = Roi.getName();

  // get information to calibrate filter parameters
  mitochondriaSize = 0.5; //microns
  getPixelSize(unit, pixelWidth, pixelHeight);
  unitFactor = calculateUnitConversion(imgTitle,unit);
  pixelSamplUm = unitFactor * pixelWidth;

  // calibrate filter parameters in pixels
  backSubtractRadius = floor(5 * mitochondriaSize / pixelSamplUm + 0.5);
  //FeatureJ-Laplacian interprets parameters in physical units
  LoGScale = 2 * mitochondriaSize;
  CLAHEKernel = floor(10*mitochondriaSize / pixelSamplUm + 0.5);
  CLAHEKernel = 2 * floor(CLAHEKernel/2) + 1;  // even size
  run("Duplicate...", "use");
  run("Remove Overlay");
  sliceID = getImageID();
  if (selectionType()>0) { run("Add Selection..."); }
  run("Subtract Background...", "rolling="+backSubtractRadius+" disable");

  rename(imgTitle+"_"+suffix);
  run("Duplicate...", " ");
  if (selectionType()>0) {
    setBackgroundColor(0, 0, 0);
    run("Clear Outside");
  }
  filteredID = getImageID();
  run("FeatureJ Laplacian", "compute smoothing="+LoGScale);
  if (aggressive) {
    run("Multiply...", "value=-1.000");
    run("Conversions...", " ");
    run("16-bit");
    run("Conversions...", "scale");
    run("8-bit");
    setAutoThreshold("Triangle dark");
  } else {
    run("8-bit");
    run("Invert");
    run("Enhance Local Contrast (CLAHE)", "blocksize="+CLAHEKernel+" histogram=256 maximum=3 mask=*None* fast_(less_accurate)"); //10
    setAutoThreshold("Yen dark");
  }

  run("Convert to Mask");
  segmID = getImageID();
  rename(imgTitle+"_"+suffix+" - mitochondria");
  selectImage(filteredID);
  close();
  selectImage(sliceID);
  run("Select None");
  run("Hide Overlay");
  selectImage(imgID);
  return newArray(sliceID,segmID);
}


function analyzeMitochondria(segmID,fullTitle,cellID,cellArea) {
  selectImage(segmID);
  run("Duplicate...", " ");

  // skeleton analysis
  run("Skeletonize (2D/3D)");
  skelID = getImageID();
  getPixelSize(unit, pixelWidth, pixelHeight);
  run("Analyze Skeleton (2D/3D)", "prune=none calculate");
  selectWindow("Longest shortest paths");
  close();
  selectWindow("Tagged skeleton");
  close();

  // gather length and number of branches
  nSkel = nResults;
  mLength = newArray();
  mBranches = newArray();
  spx = newArray();
  spy = newArray();
  for (i=0; i<nSkel; i++) {
    l = getResult("Longest Shortest Path", i);
    b = getResult("# Branches", i);
    x = getResult("spx", i);
    y = getResult("spy", i);
    // transform x and y to pixels
    x /= pixelWidth;
    y /= pixelHeight;

    mLength = Array.concat(mLength,l);
    mBranches = Array.concat(mBranches,b);
    spx = Array.concat(spx,x);
    spy = Array.concat(spy,y);
  }
  selectImage(skelID);
  close();

  // analyze particles
  run("Set Measurements...", "area standard centroid center perimeter bounding fit shape feret's integrated area_fraction redirect=None decimal=3");
  selectImage(segmID);

  run("Analyze Particles...", "clear record add");
  if (nResults != nSkel) {
    showMessage("Houston, we have a problem...");
  }
  roiManager("show none");
  selectImage(segmID);
  run("Invert");
  run("RGB Color");
  nMito = nResults;

  mitoClassesArea = initializeClassesArray();

  // for each segmented mitochondria determine the shape
  for (i=0; i<nMito; i++) {
    roiManager("select",i);
    xPos = getResult("XStart", i);
    yPos = getResult("YStart", i);
    area = getResult("Area", i);
    perimeter = getResult("Perim.", i);
    circularity = getResult("Circ.", i);
    bx = getResult("Width", i);
    by = getResult("Height", i);
    mass = area/(bx*by);
    feretMin = getResult("MinFeret", i);
    solidity = getResult("Solidity", i);
    aspectRatio = getResult("AR", i);

    done = false;
    for (j=0; j<nSkel && !done; j++) {
      refX = spx[j];
      refY = spy[j];
      if (Roi.contains(refX, refY)) {
        done = true;
        length = mLength[j];
        Nbranches = mBranches[j];
        shape = classifyMitochodria(length,Nbranches,area,perimeter,circularity,mass,feretMin,solidity,aspectRatio);

        colorMitochondria(shape,xPos,yPos);
      }
    }
    // if it does not find any skeleton associated to the mitochondria, then do
    // the classification without considering the length
    if (!done) {
        length = -1;
        Nbranches = 0;
        shape = classifyMitochodria(length,Nbranches,area,perimeter,circularity,mass,feretMin,solidity,aspectRatio);
        colorMitochondria(shape,xPos,yPos);
    }
    updateClassesArea(mitoClassesArea, shape, area);

    if ((shape=="filament" || shape=="rod") && (length>0)) {
      addMeasuresToLengthTable(MitochondriaLengthTable,fullTitle,cellID,shape,area,length,cellArea,unit);
    }
  }

  mitoClassesFractions = convertClassesAreaToFractions(mitoClassesArea);

  roiManager("show none");
  roiManager("reset");
  run("Select None");

  if (!isOpen(mitochondriaLegendName)) {
    makeLegend(mitochondriaLegendName);
  }
  return mitoClassesFractions;
}


function ROIs2Overlays(checkOverlays,deleteFromROI) {
  // Transform all rois to overlays
  // Don't do anything if both rois and overlays are already present
  n = roiManager("count");
  if (n>0) {
    // check first that there are no overlays
    if (checkOverlays && Overlay.size>0) {
        showMessage("ERROR: can not have overlays and rois at the same time!");
        Overlay.show;
        exit();
    }
    roiManager("Show All without labels");
    run("From ROI Manager");
    if (deleteFromROI) {
      roiManager("reset");
      Overlay.show;
    } else {
      roiManager("Show All with labels");
    }
  }
}


function Overlays2ROIs() {
  // transform all overlays to rois
  // delete duplicates and keep overlays in place
  n = Overlay.size;
  if (n>0) {
    roiManager("reset");
    run("To ROI Manager");
    roiManager("Show All without labels");
    run("From ROI Manager");
  }
}


function randomColor(){
    cAlpha = 100;
    r = round(random()*253+1);
    g = round(random()*253+1);
    b = round(random()*253+1);
    rh = toHex(r); gh = toHex(g); bh = toHex(b);
    fAlpha = toHex(255*cAlpha/100);
    hex= "#" + pad(fAlpha) + ""+pad(rh) + ""+pad(gh) + ""+pad(bh);

    return hex;
}


function pad(n) {
    n = toString(n);
    if(lengthOf(n)==1) n = "0"+n;
    return n;
}


function isRoiDuplicate(nr) {
   // check if roi with given index is a duplicate
   isDuplicate = false;
   n = roiManager("count");
   if (n > nr) {
     // get reference values
     roiManager("Select",nr);
     List.setMeasurements;
     bxRef = List.getValue("BX");
     byRef = List.getValue("BY");
     faRef = List.getValue("FeretAngle");
     // loop over other rois
     done = false;
     for (i=0; i<n && (!done); i++) {
        if (i!=nr) {
          roiManager("Select",i);
          List.setMeasurements;
          bx = List.getValue("BX");
          by = List.getValue("BY");
          fa = List.getValue("FeretAngle");
          if (bx==bxRef && by==byRef && fa==faRef) {
            done = true;
            isDuplicate = true;
          }
        }
     }
     run("Select None");
   }
   return isDuplicate;
}


function calculateUnitConversion(imgTitle,unit){
  //NOTE: currently the toolset is hardcoded to only accept images with units
  // in micrometers
  unitFactor = 1;
  if (unit == "microns" || unit == getInfo("micrometer.abbreviation")) {
    unitFactor = 1;
  } else if (unit == "nm") {
    unitFactor = 0.001;
  } else {
    showMessage("WARNING! Physical unit in file "+imgTitle+" not recognized ("+unit+")");
  }
  return unitFactor;
}


function renameRois(){
  n = roiManager("count");
  for (j=0; j<n; j++) {
    roiManager("select", j);
    cellName = "Cell "+(j+1);
    roiManager("Rename", cellName);
  }
  roiManager("Show All with labels");
  n = roiManager("count");
  if (n>0) {roiManager("Select",n-1);}
}


function combineImages(imgID, segID) {
  selectImage(imgID);
  run("RGB Color");
  getDimensions(Width, Height, NChannels, NSlices, NFrames);
  run("Canvas Size...", "width="+Width*3+" height="+Height+" position=Top-Left");
  selectImage(segID);
  run("Copy");
  selectImage(imgID);
  run("Paste");
  run("Canvas Size...", "width="+Width*2+" height="+Height+" position=Top-Left");
  selectImage(segID);
  close();
}


function classifyMitochodria(length,Nbranches,area,perimeter,circularity,mass,feretMin,solidity,aspectRatio) {

  if (area < minAbsArea) { return "junk"; }
  if (area < minCondArea && solidity < maxJunkSolidity) { return "junk"; }

  if (length > thresholdNetworkLength ) {
    return "filament";
  }
  if (length > minNetworkLength && feretMin > minNetworkLinearExtension && solidity < maxNetworkCompactness) {
    return "filament";
  }

  if (circularity > minPunctaCircularity && feretMin < maxPunctaLinearExtension && area < maxPunctaArea && aspectRatio < maxPunctaAspectRatio) {
     return "puncta";
   }

   if (length < maxSwollenLength && area > minSwollenArea && circularity > minSwollenCircularity && solidity > minSwollenCompactness && feretMin > minSwollenLinearExtension && aspectRatio < maxSwollenAspectRatio) {
     return "swollen";
   }

  return "rod";
}


function colorMitochondria(shape, xPos, yPos) {
    if (shape=="filament")     { setForegroundColor(141, 10, 255); }  // magenta
    else if (shape=="puncta")  { setForegroundColor(255, 109, 0);  }  // orange
    else if (shape=="junk")    {
      if (displayJunk) {setForegroundColor(0, 0, 0);}  // black
      else {setForegroundColor(255, 255, 255);}  // white
    }
    else if (shape=="rod")     { setForegroundColor(0, 166, 0);    } // green
    else if (shape=="swollen") { setForegroundColor(0, 0, 255);    } // blue
    else {
      showMessage("Houston, we have an unidentified object on the radar...");
    }
    floodFill(xPos, yPos, "8-connected");
}


function checkAndSegment() {
    if (nImages < 1) {
        showMessage("no image open!\n");
        exit();
    }
    if (bitDepth()==24 || !is("grayscale")){
        showMessage("Are you sure you activated/selected the correct image? I can't process "+getTitle()+"!\n");
        exit();
    }
    getPixelSize(unit, pixelWidth, pixelHeight);
    if (!(unit == "microns" || unit == "micron" || unit == getInfo("micrometer.abbreviation"))) {
      exit("Error","The program currently accepts only images with physical units in micron ("+unit+" given)");
    }

    setOption("BlackBackground", true);

    type = selectionType();
    cellID = roiManager("index");
    if (type<0 || cellID<0) {
        showMessage("no cell selected!\n");
        exit();
    }

    setBatchMode(true);

    fullID = getImageID();
    fullTitle = getTitle();

    // check if user has openend a new image while not closing the previous one
    if (isWorkingOnNewImage(fullTitle)) {
      if (rootImgName) {
        prevImagesStillOpen = false;
        for (i=1; i<=nImages; i++) {
          selectImage(i);
          if (startsWith(getTitle(),rootImgName))  prevImagesStillOpen = true;
        }
        if (prevImagesStillOpen) {
          showMessage("There are images and/or results from "+rootImgName+" still open.\nClose them before starting to work on "+fullTitle);
          exit();
        }
      }
    }

    rootImgName = fullTitle;

    selectImage(fullID);
    rootDirName = getInfo("image.directory");
    ids = segmentMitochondria();
    segmID = ids[1];

    cellArea = estimateCellArea(segmID);

    selectImage(fullID);
    mitoClassesFractions = analyzeMitochondria(segmID,fullTitle,cellID,cellArea);

    combineImages(ids[0],segmID);

    selectImage(fullID);
    Overlays2ROIs();
    renameRois();

    // write results for this cell to the (existing) Table
    addMeasuresToTable(MitochondriaResultsTable,fullTitle,cellID,mitoClassesFractions);

    setBatchMode("exit and display");
    run("Tile");
    selectImage(fullID);

    return mitoClassesFractions;
}


function makeLegend(legendTitle) {
  newImage(legendTitle, "RGB", 280, 160, 1);
  step = 30;

  setColor(141, 10, 255);  // magenta
  setLineWidth(10);
  Overlay.drawRect(10, 10, 30, 10);
  setColor(0, 0, 0);
  setFont("Arial", 20, "antialiased");
  Overlay.drawString("filaments network", 55, 30);

  setColor(0, 166, 0); // green
  setLineWidth(10);
  Overlay.drawRect(10, 10+step, 30, 10);
  setColor(0, 0, 0);
  setFont("Arial", 20, "antialiased");
  Overlay.drawString("rods / intermediate", 55, 30+step);

  setColor(255, 109, 0); // orange
  setLineWidth(10);
  Overlay.drawRect(10, 10+2*step, 30, 10);
  setColor(0, 0, 0);
  setFont("Arial", 20, "antialiased");
  Overlay.drawString("puncta / fragmented", 55, 30+2*step);

  setColor(0, 0, 255); // blue
  setLineWidth(10);
  Overlay.drawRect(10, 10+3*step, 30, 10);
  setColor(0, 0, 0);
  setFont("Arial", 20, "antialiased");
  Overlay.drawString("swollen", 55, 30+3*step);

  if (displayJunk) {
    setColor(0, 0, 0); // black
    setLineWidth(10);
    Overlay.drawRect(10, 10+4*step, 30, 10);
    setColor(0, 0, 0);
    setFont("Arial", 20, "antialiased");
    Overlay.drawString("junk", 55, 30+4*step);
  }

  Overlay.show();
}


function segmentMitochondriaFromAllCells() {
    if (Overlay.size>0) {
      Overlays2ROIs();
      renameRois();
    }
    n = roiManager("count");
    if (n==0) {
      showMessage("Stopping", "no cell outlines found!");
    }

    imgTitle = getTitle();
    imgID = getImageID();

    mitoImageClassesFractions = initializeClassesArray();
    for (i=0; i<n; i++) {
        roiManager("select",i);
        mitoClassesFractions = checkAndSegment();
        sumMeasureToImageClasses(mitoImageClassesFractions,mitoClassesFractions);
    }
    averageImageClassesFractions(mitoImageClassesFractions,n);

    updateSummaryResults(MitochondriaSummaryTable,imgTitle,n,mitoImageClassesFractions);
    selectImage(imgID);
}


function segmentMitochondriaBatch(){
  //ask for input directory
  dirIn = getDirectory("Choose Directory with .tif Images containing cells outlines");
  dirOut = dirIn+File.separator+subDirCellsName+File.separator;

  list = getFileList(dirIn);
  listFiles = newArray();
  for (i=0; i<list.length; i++) {
    if (endsWith(list[i], ".tif"))
        listFiles = Array.concat(listFiles,list[i]);
  }

  if (listFiles.length==0) {
    showMessage("no files with extension .tif found in"+dirIn+"!");
    exit();
  }

  //clean the environment
  run("Close All");
  roiManager("reset");
  if (isOpen(MitochondriaResultsTable)) {
    selectWindow(MitochondriaResultsTable);
    run("Close");
  }
  if (isOpen(MitochondriaSummaryTable)) {
    selectWindow(MitochondriaSummaryTable);
    run("Close");
  }
  if (isOpen(MitochondriaLengthTable)) {
    selectWindow(MitochondriaLengthTable);
    run("Close");
  }

  // load every image and process all the cells/rois stored
  for ( i=0; i<listFiles.length; i++ ) {
    open(dirIn + listFiles[i] );
    imgID = getImageID();
    Overlays2ROIs();
    segmentMitochondriaFromAllCells();
    saveEverything(false,false);
    run("Close All");
  }

  // save results table
  if (isOpen(MitochondriaResultsTable)) {
    outputResultsFile = dirOut+MitochondriaResultsFile;
    IJ.renameResults(MitochondriaResultsTable,"Results");
    updateResults();
    selectWindow("Results");
    save(outputResultsFile);
    IJ.renameResults(MitochondriaResultsTable);
  }
  if (isOpen(MitochondriaSummaryTable)) {
    outputSummaryFile = dirOut+MitochondriaSummaryFile;
    IJ.renameResults(MitochondriaSummaryTable,"Results");
    updateResults();
    selectWindow("Results");
    save(outputSummaryFile);
    IJ.renameResults(MitochondriaSummaryTable);
  }
  if (isOpen(MitochondriaLengthTable)) {
    outputLengthFile = dirOut+MitochondriaLengthFile;
    selectWindow(MitochondriaLengthTable);
    saveAs("Text",outputLengthFile);
  }
  // clean up
  roiManager("reset");
  showMessage("Done!");
}


function estimateCellArea(segmID){
  selectImage(segmID);
  title = getTitle();
  run("Select None");

  run("mask2convex hull", "imp=["+title+"]");

  getStatistics(cellArea);
  run("Select None");

  return cellArea;
}


function isWorkingOnNewImage(title) {
  if (rootImgName == "") {
    return true;
  }
  if (rootImgName != title) {
    return true;
  } else {
    return false;
  }
}


function initializeClassesArray() {
  // order of classes
  // 0: "filament" 1: "rod" 2: "puncta" 3: "swollen"
  mitoClasses = newArray(0,0,0,0);
  return mitoClasses;
}


function updateClassesArea(mitoClassesArea, shape, area) {
  idx = c2i(shape);
  if (idx>=0) {
    mitoClassesArea[idx] = mitoClassesArea[idx]+area;
  }
}


function convertClassesAreaToFractions(mitoClassesArea) {
  mitoClassesFractions = newArray(mitoClassesArea.length);
  totalArea = 0;
  for (i=0; i<mitoClassesArea.length; i++) {
    totalArea = totalArea + mitoClassesArea[i];
  }

  for (i=0; i<mitoClassesArea.length; i++) {
    mitoClassesFractions[i] = mitoClassesArea[i]/totalArea;
  }

  return mitoClassesFractions;
}


function c2i(shape){
  if (shape=="filament") { return 0; }
  else if (shape=="rod") { return 1; }
  else if (shape=="puncta") { return 2; }
  else if (shape=="swollen") { return 3; }
  return -1;
}


function i2c(idx){
  if (idx==0) { return "filament"; }
  else if (idx==1) { return "rod"; }
  else if (idx==2) { return "puncta"; }
  else if (idx==3) { return "swollen"; }
  return "unknown";
}


function initializeLengthTable(tableName){
  run("Table...", "name=["+tableName+"]");
	print("["+tableName+"]", "\\Headings:Image\tCell\tClass\tArea\tLength\tCellArea\tUnit");
}


function addMeasuresToLengthTable(tableName,fullTitle,cellID,shape,area,length,cellArea,unit){
  if (!isOpen(tableName)) {
    initializeLengthTable(tableName);
  }
  print("["+tableName+"]",fullTitle+"\t"+d2s(cellID+1,0)+"\t"+shape+"\t"+d2s(area,2)+"\t"+d2s(length,2)+"\t"+d2s(cellArea,2)+"\t"+unit);
}


function addMeasuresToTable(MitochondriaResultsTable,fullTitle,cellID,mitoClassesFractions){
  run("Clear Results");
  if (isOpen(MitochondriaResultsTable)) {
    IJ.renameResults(MitochondriaResultsTable,"Results");
    updateResults();
  }
  lastResult = nResults;
  if (cellID<0) {
    idx = lastResult;
  } else {
    idx = cellID + 1;
  }
  setResult("File", lastResult, fullTitle);
  setResult("Cell", lastResult, idx);
  for(i=0; i<mitoClassesFractions.length; i++){
    setResult(i2c(i), lastResult, mitoClassesFractions[i]);
  }
  IJ.renameResults(MitochondriaResultsTable);
}


function sumMeasureToImageClasses(mitoImageClassesFractions, mitoClassesFractions){
  for (i=0; i<mitoClassesFractions.length; i++) {
    mitoImageClassesFractions[i] = mitoImageClassesFractions[i] + mitoClassesFractions[i];
  }
}


function averageImageClassesFractions(mitoImageClassesFractions, n){
  for (i=0; i<mitoImageClassesFractions.length; i++) {
    mitoImageClassesFractions[i] = mitoImageClassesFractions[i] / n;
  }
}


function updateSummaryResults(SummaryTable,fullTitle,n,ClassesFractions){
  run("Clear Results");
  if (isOpen(SummaryTable)) {
    IJ.renameResults(SummaryTable,"Results");
    updateResults();
  }
  lastResult = nResults;
  setResult("File", lastResult, fullTitle);
  setResult("NCells", lastResult, n);
  for(i=0; i<ClassesFractions.length; i++){
    setResult(i2c(i), lastResult, ClassesFractions[i]);
  }
  IJ.renameResults(SummaryTable);
}
