# Reproduction of DeepLineDP
The aim of this project was to reproduce the following research paper:
> _C. Pornprasit; C. Kla Tantithamthavorn, [DeepLineDP: Towards a Deep Learning Approach for Line-Level Defect Prediction (2023)](https://ieeexplore.ieee.org/document/9689967)_.

describe the necessary steps that we took throughout the proces and finally try to improve on the already achieved results.

## Project links
Another aim of the project was to document the whole process, plan and share responsibilities, 
therefore we used following tools (links to actual projects):

![overleaf.png](readme-images/overleaf.png) [Overleaf](https://www.overleaf.com/project/6401cb6ce8e0e36a2d64e237) \
![trello.png](readme-images/trello.png) [Trello](https://trello.com/b/rlZQmIfa/pbr-zadania)

## Authors
![github.png](readme-images/github.png) [Kamila Sproska](https://github.com/ksproska)
<br>
![github.png](readme-images/github.png) [Dominik Polak](https://github.com/domppolak)

-------
## Reproduction
### Our approach towards extending the original repository
Original repository for research paper was separated into two:
- supplementary materials (scripts for training models) - 
the original from [awsm-research/DeepLineDP](https://github.com/awsm-research/DeepLineDP) 
was pasted into [DeepLineDP](/DeepLineDP) folder.
- database - original from [awsm-research/line-level-defect-prediction](https://github.com/awsm-research/line-level-defect-prediction)
was pasted into [DeepLineDP/datasets](/DeepLineDP/datasets) folder.

We decided to merge two repositories in order to make reproduction easier.

### Preparation for reproduction
Since models require CUDA to be able to run and not all computers can have it installed, we decided to do the reproduction on Google colab. \
For this reason there are a couple of steps required to do before reproduction itself.

1. Download this repository using _Download ZIP_ option. \
![github-download-zip.png](readme-images/github-download-zip.png)

2. Upload folder to drive to the main catalog (for this example the folder is called _M6_). \
![google-drive-placement.png](readme-images/google-drive-placement.png)

3. Go to uploaded folder and find [reproduction.ipynb](/reproduction.ipynb) script. 
Choose _Open with > Google Colaboratory_ option. \
![open-reproduction-script.png](readme-images/open-reproduction-script.png)

4. Change runtime type to GPU _Change runtime type -> GPU -> Save_. \
![change-runtme-menu.png](readme-images/change-runtme-menu.png)
![change-to-GPU.png](readme-images/change-to-GPU.png)

### Running reproduction script
Overview of the whole process: 

![overview.png](readme-images/overview.png)

All those steps have been described in [reproduction.ipynb](/reproduction.ipynb), however most notable remarks to keep in mind are:
- When mounting Google Drive make sure you followed all the popup instructions and followed the setup correctly. 
At the end setup should look somewhat like this: \
![google-collab-setup.png](readme-images/google-collab-setup.png)
- Not all lines need to be run each time, however all `pip install` commands have to be run at the beginning of each session.
- The file is uploaded without cleared output, so that it is easier to recognize whether cell ran correctly (outputs should be similar).
- **To check reporoduction with applied changes go to /content/drive/MyDrive/M6/DeepLineDP/script/preprocess_data.py and change flag `ignore_imports` to `True`**

### Results of the reproduction
#### For all databases
| file-Effort@Top20Recall (↘)                                           | file-Recall@Top20LOC (↗)                                           | file-IFA (↘)                                           |
|-----------------------------------------------------------------------|--------------------------------------------------------------------|--------------------------------------------------------|
| ![](readme-images/original-all-databases/file-Effort@Top20Recall.png) | ![](readme-images/original-all-databases/file-Recall@Top20LOC.png) | ![](readme-images/original-all-databases/file-IFA.png) |

#### For activemq
| file-Effort@Top20Recall (↘)                                      | file-Recall@Top20LOC (↗)                                      | file-IFA (↘)                                      |
|------------------------------------------------------------------|---------------------------------------------------------------|---------------------------------------------------|
| ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/original-activemq/file-Recall@Top20LOC.png) | ![](readme-images/original-activemq/file-IFA.png) |

## Improvements
In order to set a specific type of change it is needed to set specific flags.
In [DeepLineDP_model.py](DeepLineDP/script/DeepLineDP_model.py) and in [preprocess_data.py](DeepLineDP/script/preprocess_data.py)
there are following flags:

| Flag                    | Function                                                  |
|-------------------------|-----------------------------------------------------------|
| ignore_imports          | Changes all import lines to comment containing `#import`  |
| replace_exceptions      | Replaces all *Exception classes to Exception              |
| remove_public_keyword   | Removes keyword public                                    |
| remove_final_keyword    | Removes keyword final                                     |
| normalize_names         | Removes whitespaces before and after each line            |
| remove_duplication_line | Removes all duplicated lines (that have already appeared) |
| add_hidden_layer        | Adds one hidden FC layer                                  |

Each flag has a default value `False` therefore in order to tes a certain type of change
it is necessary before running [reproduction script](reproduction.ipynb) to <ins>**change chosen flag(s) to `true`**</ins>.

### Exceptions replaced

|   | Original                                                         | Exceptions replaced                                                         |
|---|------------------------------------------------------------------|-----------------------------------------------------------------------------|
| ↘ | ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/exceptions-replaced-activemq/file-Effort@Top20Recall.png) |
| ↗ | ![](readme-images/original-activemq/file-Recall@Top20LOC.png)    | ![](readme-images/exceptions-replaced-activemq/file-Recall@Top20LOC.png)    |
| ↘ | ![](readme-images/original-activemq/file-IFA.png)                | ![](readme-images/exceptions-replaced-activemq/file-IFA.png)                |

### Imports replaced with comment

|   | Original                                                         | Imports replaced with comment                                           |
|---|------------------------------------------------------------------|-------------------------------------------------------------------------|
| ↘ | ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/import-replaced_activemq/file-Effort@Top20Recall.png) |
| ↗ | ![](readme-images/original-activemq/file-Recall@Top20LOC.png)    | ![](readme-images/import-replaced_activemq/file-Recall@Top20LOC.png)    |
| ↘ | ![](readme-images/original-activemq/file-IFA.png)                | ![](readme-images/import-replaced_activemq/file-IFA.png)                |

### Public remove

|   | Original                                                         | Public remove                                                           |
|---|------------------------------------------------------------------|-------------------------------------------------------------------------|
| ↘ | ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/public-replaced-activemq/file-Effort@Top20Recall.png) |
| ↗ | ![](readme-images/original-activemq/file-Recall@Top20LOC.png)    | ![](readme-images/public-replaced-activemq/file-Recall@Top20LOC.png)    |
| ↘ | ![](readme-images/original-activemq/file-IFA.png)                | ![](readme-images/public-replaced-activemq/file-IFA.png)                |

### Final remove

|   | Original                                                         | Final remove                                                          |
|---|------------------------------------------------------------------|-----------------------------------------------------------------------|
| ↘ | ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/final-replace-qctivemq/file-Effort@Top20Recall.png) |
| ↗ | ![](readme-images/original-activemq/file-Recall@Top20LOC.png)    | ![](readme-images/final-replace-qctivemq/file-Recall@Top20LOC.png)    |
| ↘ | ![](readme-images/original-activemq/file-IFA.png)                | ![](readme-images/final-replace-qctivemq/file-IFA.png)                |

### Hidden layer added

|   | Original                                                         | Hidden layer added                                                   |
|---|------------------------------------------------------------------|----------------------------------------------------------------------|
| ↘ | ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/hidden-layer-activemq/file-Effort@Top20Recall.png) |
| ↗ | ![](readme-images/original-activemq/file-Recall@Top20LOC.png)    | ![](readme-images/hidden-layer-activemq/file-Recall@Top20LOC.png)    |
| ↘ | ![](readme-images/original-activemq/file-IFA.png)                | ![](readme-images/hidden-layer-activemq/file-IFA.png)                |



### Duplicate line remove
|   | Original                                                         | Duplicate line remove                                           |
|---|------------------------------------------------------------------|-----------------------------------------------------------------|
| ↘ | ![](readme-images/original-activemq/file-Effort@Top20Recall.png) | ![](readme-images/remove-duplicate/file-Effort@Top20Recall.png) |
| ↗ | ![](readme-images/original-activemq/file-Recall@Top20LOC.png)    | ![](readme-images/remove-duplicate/file-Recall@Top20LOC.png)    |
| ↘ | ![](readme-images/original-activemq/file-IFA.png)                | ![](readme-images/remove-duplicate/file-IFA.png)                |

### Result for additional metrics

|   |                                                                     |                                                                   |
|---|------------------------------------------------------------------|----------------------------------------------------------------------|
| ↘ | ![](readme-images/additional_metrics/file-Effort@Top20Recall.png) | ![](readme-images/additional_metrics/file-Precision.png)            |
| ↗ | ![](readme-images/additional_metrics/file-Recall@Top20LOC.png)    | ![](readme-images/additional_metrics/file-MCC.png)                  |
| ↘ | ![](readme-images/additional_metrics/file-IFA.png)                | ![](readme-images/additional_metrics/file-BalancedAccuracy.png)     |

### Result for not preprocessed data

|   |                                                                     |                                                                   |
|---|------------------------------------------------------------------|----------------------------------------------------------------------|
| ↘ | ![](readme-images/notpreprocesdata/file-Effort@Top20Recall.png) | ![](readme-images/notpreprocesdata/file-Precision.png)                |
| ↗ | ![](readme-images/notpreprocesdata/file-Recall@Top20LOC.png)    | ![](readme-images/notpreprocesdata/file-MCC.png)                      |
| ↘ | ![](readme-images/notpreprocesdata/file-IFA.png)                | ![](readme-images/notpreprocesdata/file-BalancedAccuracy.png)         |
