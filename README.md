# axle-healthcare-benchmark #

Synthetic healthcare database generator and decision support benchmark

## CDA Generator ##

Generates an endless stream of CDA documents.
The structure and distribution of the content of the documents is defined in a set of models in the models/ directory (not provided).
Terminology data is read from the terminology/ directory that defines the value types and display names of all acts and coded values.

### Requires ###
* Oracle JDK 7
	* http://www.oracle.com/technetwork/java/javase/downloads/index.html
* Maven 2.2
	* apt-get install maven2
	* yum install maven2.noarch

### Before running ###
bash initialize.sh -u &lt;required-files-url&gt;

### Running ###
* nano src/main/resources/application.conf
	* Configure outputDirectory to a suitable directory
* bash start.sh

