import QtQuick 2.0
import QtQuick.Dialogs 1.0
import QtQuick.Controls 1.0
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    menuPath: "Plugins.ExportStaffMP3s"
    description: "Description goes here"
    version: "1.0"
    requiresScore: true
    pluginType: "dialog"
    id: window
    width: 360
    height: 200



    QProcess {
        id: proc
    }

    function dirname(p) {
        return (p.slice(0,p.lastIndexOf("/")+1))
    }
    
    function basename(p) {
        return (p.slice(p.lastIndexOf("/")+1))
    }

    function extension(p) {
        return (p.slice(p.lastIndexOf(".")+1))
    }
    function showObject(oObject) {
        
        if (Object.keys(oObject).length >0) {
            Object.keys(oObject)
                .filter(function(key) {
                    return oObject[key] != null;
                })
                .sort()
                .forEach(function eachKey(key) {
                    console.log("---- ---- ", key, " : <", oObject[key], ">");
                });
        }
    }
    function instrumentId2newPart(instID) {
        switch (instID) {
            case "brass.trumpet":
                instID = "trumpet"
                break;
            case "brass.trombone":
                instID = "trombone-treble"
                break;
            case "brass.sousaphone":
                instID = "bb-sousaphone-treble"
                break;
        }
        return instID
    }
    onRun: {

    }
    function getLocalPath(path) {
        path = path.replace(/^(file:\/{2})/,"")
        if (Qt.platform.os == "windows") path = path.replace(/^\//,"")
        path = decodeURIComponent(path)
        return path
    }
    function exportMP3(infile, outfile) {
        var cmd = "musescore "+infile+" -o "+outfile
        proc.start(cmd);
        var val = proc.waitForFinished(-1);
        if (val) {
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            cmd = "MuseScore3.exe "+infile+" -o "+outfile
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        }
    }
    function mkdir(path) {
        if (Qt.platform.os=="linux") {
            var cmd = "mkdir "+path
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else if (Qt.platform.os=="windows") {
            cmd = "cmd.exe /c 'Mkdir \""+path+"\"'"
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            console.log("unknown os",Qt.platform.os)
        }
    }
    function rmdir(path) {
        if (Qt.platform.os=="linux") {
            var cmd = "rm -rf "+path
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else if (Qt.platform.os=="windows") {
            var cmd = "cmd.exe /c 'rmdir /s /q \""+path+"\"'"
            proc.start(cmd);
            var val = proc.waitForFinished(-1);
            console.log(cmd)
            console.log(val)
            console.log(proc.readAllStandardOutput())
        } else {
            console.log("unknown os",Qt.platform.os)
        }
    }
    function exportStaffs(destFolder) {
        var score = curScore
        var origPath = score.path
        var cdir = dirname(origPath)
        var cname = basename(origPath)
        cname = cname.slice(0, cname.lastIndexOf('.'))
        console.log(score.scoreName, score.nstaves)
        console.log(cdir, cname)

        mkdir(destFolder+"tempFolder/")

        // all staffs
        exportMP3(cdir+cname+".mscz", destFolder+cname+"_all.mp3")
        /*
        var cmd = "musescore "+cdir+cname+".mscz -o "+destFolder+cname+"_all.mp3"
        console.log(cmd)
        proc.start(cmd);
        var val = proc.waitForFinished(-1);
        console.log(val)
        console.log(proc.readAllStandardOutput())
        */

        console.log("did all mp3")

        if (score.nstaves>1) {
            for (var staff=0; staff<score.nstaves; staff++) {
                console.log("doing staff",staff)
                readScore(origPath)

                var cur = curScore.newCursor()
                cur.staffIdx = staff
                cur.voice = 0
                cur.rewind(0)
                //showObject(cur.element.staff.part)
                if (!exportNonPitched.checked && !cur.element.staff.part.hasPitchedStaff) {
                    continue
                }
                var instID = cur.element.staff.part.instrumentId
                console.log(instID)
                var inst = cur.element.staff.part.instruments[0]
                var instLongName = inst.longName.replace(" ","_")

                writeScore(curScore, destFolder+"tempFolder/"+cname+"_"+instLongName,"mscz")

                // modify dynamics
                var offs = 0
                for (var st=0; st<score.nstaves; st++) {
                    if (st==staff) {
                        console.log("ignoring staff",st)
                        offs = 0
                    } else {
                        if (restInBackground.checked) {
                            offs = -40
                        } else {
                            offs = -100
                        }
                    }
                    cur.staffIdx = st
                    for (var voice=0; voice<4; voice++) {
                        cur.voice = voice
                        cur.rewind(0)
                        while (cur.segment) {
                            if (cur.element) {
                                if (cur.element.type==Element.CHORD) {
                                    var c = cur.element
                                    for (var i=0; i<c.notes.length; i++) {
                                        var n = c.notes[i]
                                        n.veloOffset = Math.max(-100,offs)
                                    }
                                }
                            }
                            cur.next()
                        }
                    }
                }


                writeScore(curScore, destFolder+"tempFolder/"+cname+"_"+instLongName,"mscz")


                exportMP3(destFolder+"tempFolder/"+cname+"_"+instLongName+".mscz", destFolder+cname+"_"+instLongName+".mp3")
                /*
                var cmd = "musescore "+destFolder+"tempFolder/"+cname+"_"+instLongName+".mscz -o "+destFolder+cname+"_"+instLongName+".mp3"
                console.log(cmd)
                proc.start(cmd);
                var val = proc.waitForFinished(-1);
                console.log(val)
                console.log(proc.readAllStandardOutput())
                */

            }
        }
        
        
        // remove tempfolder again
        rmdir(destFolder+"tempFolder/")        

        closeScore(curScore)
        //console.log("reading",origPath)
        readScore(origPath,false)

        Qt.quit()
    }


    Item {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        Column {
            spacing: 10

            CheckBox {
                id: exportNonPitched
                checked: false
                text: qsTr("Export non pitched staffs")
                onCheckedChanged: function () {
                }
            }

            CheckBox {
                id: restInBackground
                checked: true
                text: qsTr("Export other staffs but quieter")
                onCheckedChanged: function () {
                }
            }

            Label {
                text: qsTr("After choosing the output wait for this window to close")
            }

            Row {
                spacing: 10

                Button {
                    id : buttonSaveOutput
                    text: qsTr("Export")
                    onClicked: {
                        console.log("export")
                        saveFileDialog.open()
                    }
                }

                Button {
                    id : buttonCancel
                    text: qsTr("Cancel")
                    onClicked: {
                        Qt.quit();
                    }
                }
            }
        }
    }

    FileDialog {
        id: saveFileDialog
        title: qsTr("Output destination")
        selectExisting: false
        selectFolder: true
        selectMultiple: false
        onAccepted: {
                var filename = saveFileDialog.fileUrl.toString()
                console.log("Selected",filename)
                
                if(filename){

                    filename = getLocalPath(filename)
                    filename = dirname(filename+"/")
                    console.log("filename",filename)
                    exportStaffs(filename)

                    //Qt.quit()

                }
        }
    }
}
