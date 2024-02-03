<?xml version="1.0" encoding="UTF-8"?>
<ModuleFile xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<UiMod name="GCDsaver" version="1.24" date="01/13/2024" >
		<Author name="Talladego" email="" />
		<Description text="GCDsaver" />
		<VersionSettings gameVersion="1.4.8" windowsVersion="1.0" savedVariablesVersion="1.0" />

		<Dependencies>
			<Dependency name="EA_ActionBars" />
			<Dependency name="LibSlash" />
		</Dependencies>
		<Files>
			<File name="libs\LibStub.lua" />
			<File name="libs\LibGUI.lua" />
			<File name="libs\LibConfig.lua" />
			<File name="GCDsaverAPI.lua" />
			<File name="Emissary.Abilities.lua" />
			<File name="checks\BlackOrcChecks.lua" />
			<File name="checks\Swordmasterchecks.lua" />
			<File name="checks\Ironbreakerchecks.lua" />
			<File name="checks\Witchelfchecks.lua" />
			<File name="checks\Witchhunterchecks.lua" />
			<File name="checks\Blackguardchecks.lua" />
			<File name="checks\Warriorpriestchecks.lua" />
			<File name="checks\Disciplechecks.lua" />			
			<File name="GCDsaver.lua" />
			<File name="GCDsaver_Config.lua" />
		</Files>

		<SavedVariables>
			<SavedVariable name="GCDsaver.Settings" />
		</SavedVariables>

		<OnInitialize>
			<CallFunction name="GCDsaver.Initialize" />
		</OnInitialize>

		<OnUpdate>
			<CallFunction name="GCDsaver.OnUpdate" />
		</OnUpdate>

		<OnShutdown>
			<CallFunction name="GCDsaver.OnShutdown" />
		</OnShutdown>
	</UiMod>
</ModuleFile>
