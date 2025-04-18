using Models.PCB;
using Models.PCB.CPCB;
using Newtonsoft.Json;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class PCBService : IPCBService
    {
        private readonly ConfigSettingService configSettingService;
        private readonly StationService stationService;
        private readonly ChannelService channelService;
        private const string CPCB_GROUPNAME = "CPCBUploading";
        public PCBService(ConfigSettingService _configSettingService, StationService _stationService, ChannelService _channelService)
        {
            configSettingService = _configSettingService;
            stationService = _stationService;
            channelService = _channelService;
        }
        public void CreateCPCBChannelConfig(ChannelConfiguration channelConfiguration)
        {
            var existingConfigs = GetCPCBChannelsConfigsByStationId(channelConfiguration.StationId);
            if (existingConfigs.Any())
            {
                var matchedConfigWithSameChannel = existingConfigs.Where(e => e.ChannelId == channelConfiguration.ChannelId).FirstOrDefault();
                if (matchedConfigWithSameChannel != null)
                {
                    throw new ArgumentException($"Configuration already exists for channel : {matchedConfigWithSameChannel.ChannelName}");
                }
            }
            var channel = channelService.GetChannelById(channelConfiguration.ChannelId);
            Guid configurationId = Guid.NewGuid();
            channelConfiguration.Id = configurationId;
            channelConfiguration.ChannelName = channel.Name;            
            Models.Post.ConfigSetting setting = new Models.Post.ConfigSetting
            {
                GroupName = CPCB_GROUPNAME,
                ContentName = $"ChannelConfiguration_{configurationId}",
                ContentValue = JsonConvert.SerializeObject(channelConfiguration),
            };
            configSettingService.CreateConfigSetting(setting);
        }

        public void CreateCPCBStationConfig(StationConfiguration stationConfiguration)
        {
            var existingConfigs = GetCPCBStationsConfigs();
            if (existingConfigs.Any())
            {
                var matchedConfigWithSameStation = existingConfigs.Where(e => e.StationId == stationConfiguration.StationId).FirstOrDefault();
                if (matchedConfigWithSameStation != null)
                {
                    throw new ArgumentException($"Configuration already exists for station : {matchedConfigWithSameStation.StationName}");
                }
            }
            var station = stationService.GetStationById(stationConfiguration.StationId);
            Guid configurationId = Guid.NewGuid();
            stationConfiguration.Id = configurationId;
            stationConfiguration.StationName = station.Name;
            Models.Post.ConfigSetting setting = new Models.Post.ConfigSetting
            {
                GroupName = CPCB_GROUPNAME,
                ContentName = $"StationConfiguration_{configurationId}",
                ContentValue = JsonConvert.SerializeObject(stationConfiguration),
            };
            configSettingService.CreateConfigSetting(setting);
        }
        public IEnumerable<StationConfiguration> GetCPCBStationsConfigs()
        {
            List<StationConfiguration> stationConfigurations = new List<StationConfiguration>();
            var stationsConfigs = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName.StartsWith("StationConfiguration_"));
            foreach(var config in stationsConfigs)
            {
                var stationConfiguration = JsonConvert.DeserializeObject<StationConfiguration>(config.ContentValue);
                var station = stationService.GetStationById(stationConfiguration.StationId);
                if (station != null)
                {
                    if (station.Active)
                    {
                        stationConfigurations.Add(stationConfiguration);
                    }
                }
            }
            return stationConfigurations;
        }
        public IEnumerable<ChannelConfiguration> GetChannelsConfigs()
        {
            List<ChannelConfiguration> channelConfigurations = new List<ChannelConfiguration>();
            var channelsConfig = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName.StartsWith("ChannelConfiguration_"));
            foreach (var config in channelsConfig)
            {
                var channelConfiguration = JsonConvert.DeserializeObject<ChannelConfiguration>(config.ContentValue);
                var channel = channelService.GetChannelById(channelConfiguration.ChannelId);
                if (channel != null)
                {
                    if (channel.Active)
                    {
                        channelConfigurations.Add(channelConfiguration);
                    }
                }
            }
            return channelConfigurations;
        }
        public IEnumerable<ChannelConfiguration> GetCPCBChannelsConfigsByStationId(int stationId)
        {
            return GetChannelsConfigs().Where(e => e.StationId == stationId);
        }

        public StationConfiguration GetCPCBStationConfigurationById(string id)
        {
            var stationConfigurations = GetCPCBStationsConfigs();
            return stationConfigurations.Where(e => e.Id == Guid.Parse(id)).FirstOrDefault();
        }

        public ChannelConfiguration GetCPCBChannelConfigurationById(string id)
        {
            var channelConfigurations = GetChannelsConfigs();
            return channelConfigurations.Where(e => e.Id == Guid.Parse(id)).FirstOrDefault();
        }

        public void UpdateCPCBStationConfig(StationConfiguration stationConfiguration)
        {
            var existingConfigs = GetCPCBStationsConfigs().Where(e=>e.Id!=stationConfiguration.Id);
            if (existingConfigs.Any())
            {
                var matchedConfigWithSameStation = existingConfigs.Where(e => e.StationId == stationConfiguration.StationId).FirstOrDefault();
                if (matchedConfigWithSameStation != null)
                {
                    throw new ArgumentException($"Configuration already exists for station : {matchedConfigWithSameStation.StationName}");
                }
            }
            var station = stationService.GetStationById(stationConfiguration.StationId);
            stationConfiguration.StationName = station.Name;
            var stationConfigurationToEdit = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName == $"StationConfiguration_{stationConfiguration.Id}").FirstOrDefault();
            if (stationConfigurationToEdit == null)
            {
                throw new ArgumentException("Cannot find configuration to update.");
            }            
            stationConfigurationToEdit.ContentValue = JsonConvert.SerializeObject(stationConfiguration);
            configSettingService.UpdateConfigSetting(stationConfigurationToEdit);
        }

        public void UpdateCPCBChannelConfig(ChannelConfiguration channelConfiguration)
        {
            var existingConfigs = GetCPCBChannelsConfigsByStationId(channelConfiguration.StationId);
            if (existingConfigs.Any())
            {
                var matchedConfigWithSameChannel = existingConfigs.Where(e => e.ChannelId == channelConfiguration.ChannelId).FirstOrDefault();
                if (matchedConfigWithSameChannel != null)
                {
                    throw new ArgumentException($"Configuration already exists for channel : {matchedConfigWithSameChannel.ChannelName}");
                }
            }
            var channel = channelService.GetChannelById(channelConfiguration.ChannelId);
            channelConfiguration.ChannelName = channel.Name;
            var channelConfigurationToEdit = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName == $"ChannelConfiguration_{channelConfiguration.Id}").FirstOrDefault();
            if (channelConfigurationToEdit == null)
            {
                throw new ArgumentException("Cannot find configuration to update.");
            }
            channelConfigurationToEdit.ContentValue = JsonConvert.SerializeObject(channelConfiguration);
            configSettingService.UpdateConfigSetting(channelConfigurationToEdit);
        }

        public void DeleteCPCBStationConfig(string id)
        {
            var stationConfig = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName == $"StationConfiguration_{id}").FirstOrDefault();
            if (stationConfig == null)
            {
                throw new ArgumentException("Cannot find configuration to delete.");
            }
            configSettingService.DeleteConfigSetting(stationConfig.Id);
        }

        public void DeleteCPCBChannelConfig(string id)
        {
            var channelConfig = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName == $"ChannelConfiguration_{id}").FirstOrDefault();
            if (channelConfig == null)
            {
                throw new ArgumentException("Cannot find configuration to delete.");
            }
            configSettingService.DeleteConfigSetting(channelConfig.Id);
        }

        public void UpdateCPCBUploadSettings(UploadSettings uploadSettings)
        {
            var settings = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName == "UploadSettings").FirstOrDefault();
            if (settings == null)
            {
                Models.Post.ConfigSetting configSetting = new Models.Post.ConfigSetting
                {
                    GroupName = CPCB_GROUPNAME,
                    ContentName = "UploadSettings",
                    ContentValue = JsonConvert.SerializeObject(uploadSettings)
                };
                configSettingService.CreateConfigSetting(configSetting);
            }
            else
            {
                settings.ContentValue = JsonConvert.SerializeObject(uploadSettings);
                configSettingService.UpdateConfigSetting(settings);
            }
        }

        public UploadSettings GetCPCBUploadSettings()
        {
            var settings = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName == "UploadSettings").FirstOrDefault();
            if (settings != null)
            {
                return JsonConvert.DeserializeObject<Models.PCB.UploadSettings>(settings.ContentValue);
            }
            else
            {
                return new UploadSettings
                {
                    LiveUrl = "",
                    DelayUrl = "",
                    LiveInterval = 60,
                    DelayInterval = 60,
                    LiveRecords = 1,
                    DelayRecords = 1
                };
            }
        }
    }
}
