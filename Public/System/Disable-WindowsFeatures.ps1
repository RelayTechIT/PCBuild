# Disable Recall
Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart

# Disable Remote Desktop Client
Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-RemoteDesktopConnection" -NoRestart
