module Main

/**
 * Series 1
 * 
 * Cornelius Ries
 * Piotr Kosytorz
 */

import IO;
import List;
import String;

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::jdt::m3::Core;
import lang::java::jdt::m3::AST;

import util::Webserver;
import util::ValueUI;

/**
 * Own modules import
 */
import Utils;
import Rater;
import Types;
import Type;
import Configuration;

import VolumeAnalyzer;
import ComplexityAnalyzer;
import DuplicationsAnalyzer;

private map[str, loc] projects = ();
private map[str, value] scores = ();

private void addProject(str key, loc l){
	projects[key] = l;
}

private Response proceedRequest(Request r) {
	
	str path = "";
	get(path) = r; 
	loc localPath  = projectLocation + "/www/" + path;
	
	if (endsWith(localPath.uri, ".css")) {
		return response(ok(), "text/css", (), readFile(localPath));
	}
	
	if (endsWith(localPath.uri, ".html")) {
		return response(ok(), "text/html", (), readFile(localPath));
	}
	
	if (endsWith(localPath.uri, ".js")) {
		return response(ok(), "text/javascript", (), readFile(localPath));
	}

	return response(readFile(localPath));
}

public void startServe(){

	addProject("test", testProject);
	addProject("smallSQL", smallSqlProject);
	addProject("hsqlDB", hqSqlProject);

	serve(serveAddress, Response (Request r){
		switch(r){
			case get(/analyze/) : return {
				str project = r.parameters["project"];
				int threshold = toInt(r.parameters["threshold"]);
				generateReport(projects[project], threshold);
				return response("done");
			}
			case get(/projects/) : return response(projects);
			case get(/scores/) : return response(scores);
			case get(/files/) : return response(filesResult);
			case get(/duplications/) : return response(duplicationResult);
			default: return proceedRequest(r);
	
		}
    });

}

public void stopServe(){
	shutdown(serveAddress);
	projects = ();
}
 
/**
 * The main method generates some nice html for the analysis and json for the duplication
 */
public void generateReport(loc location, int duplicationThreshold){
	
	// m3 object
 	M3 m = createM3FromEclipseProject(location);

	// project files
 	set[loc] files = extractFilesFromM3(m);
 	
 	// project volume (sum)
	int volume = getVolume(files, location);	
	
	// create the ast
	set[Declaration] declarations = createAstsFromEclipseProject(location, true);		
	
	// units analysis 
	astInfo ai = analyzeAST(declarations);
	unitsCompleity = ai.ui;
	
	// testing analysis
	int numberOfAsserts = ai.numberOfAsserts;
	int numberOfUnits = size(unitsCompleity);
	
	// duplications count
	int dupCount = detectClones(declarations, duplicationThreshold);
	
	// scores
	score volumeS = volumeScore(volume);
	unitScore unitCCS = unitCCScore(unitsCompleity, volume);
	unitScore unitSS = unitSizeScore(unitsCompleity, volume);
	dupScore dupS = duplicationScore(dupCount, volume);
	testingScore testingS = testingScore(numberOfAsserts, numberOfUnits);
	unitScore interfaceS = unitInterfaceScore(unitsCompleity);
	
	score maintainability = avarageScore([volumeS, unitCCS.s, unitSS.s, dupS.s, testingS.s]);
	score analysability = avarageScore([volumeS, unitSS.s, dupS.s, testingS.s]);
	score changeability = avarageScore([unitCCS.s, dupS.s]);
	score stability = testingS.s;
	score testability = avarageScore([unitCCS.s, unitSS.s, testingS.s]);
	
	scores = ();
	scores["volume"] = volume;
	scores["duplications"] = dupCount;
	
	scores["volumeS"] = volumeS;
	scores["unitCCS"] = unitCCS;
	scores["unitSS"] = unitSS;
	scores["dupS"] = dupS;
	scores["testingS"] = testingS;
	scores["interfaceS"] = interfaceS;
	scores["numberOfUnits"] = numberOfUnits;
	
	scores["maintainability"] = maintainability;
	scores["analysability"] = analysability;
	scores["changeability"] = changeability;
	scores["stability"] = stability;
	scores["testability"] = testability;
		
}