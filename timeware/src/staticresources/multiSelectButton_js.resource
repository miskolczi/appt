var divHover = '';
 
/* When a multi select button is clicked this method executes. First it hides all options for every
multiselect button on the page the show but options for the button that was clicked. This way, if
you click one button and then click another button the options on the first will disappear. */
 
function showOptions(objId){
	var multiButtons = document.getElementsByName("multiButton");
	for(var i=0; i &lt; multiButtons.length; i++){
		multiButtons[i].style.position = '';
	}
 
	var multiButtonOpts = document.getElementsByName("multipButtonOpts");
	for(var i=0; i &lt; multiButtonOpts.length; i++){
		multiButtonOpts[i].style.display = 'none';
	}		
 
	document.getElementById('CloneMenu' + objId).style.display = 'block';
	document.getElementById('CloneMenu' + objId).style.top = '17px';
	document.getElementById('button' + objId).style.position = 'relative';
}
 
/*Any time the document is click and the mouse is not over a multiselect button hide all options */
document.onclick = function(){
	if(divHover == ''){
		var multiButtons = document.getElementsByName("multiButton");
		for(var i=0; i &lt; multiButtons.length; i++){
			multiButtons[i].style.position = '';
		}
 
		var multiButtonOpts = document.getElementsByName("multipButtonOpts");
		for(var i=0; i &lt; multiButtonOpts.length; i++){
			multiButtonOpts[i].style.display = 'none';
		}
	}
}