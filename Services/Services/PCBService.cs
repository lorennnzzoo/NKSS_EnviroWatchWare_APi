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
            //update channel is cpcb to true
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
            UpdateStationCPCBFlag(true, station);
        }
        public void UpdateStationCPCBFlag(bool isCpcb,Models.Station station)
        {
            Models.Put.Station stationPut = new Models.Put.Station
            {
                Id = station.Id,
                CompanyId = station.CompanyId,
                MonitoringTypeId = station.MonitoringTypeId,
                Name = station.Name,
                IsCpcb = true,
                IsSpcb = false,
            };
            stationService.UpdateStation(stationPut);
        }
        public IEnumerable<StationConfiguration> GetCPCBStationsConfigs()
        {
            List<StationConfiguration> stationConfigurations = new List<StationConfiguration>();
            var stationsConfigs = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName.StartsWith("StationConfiguration_"));
            foreach(var config in stationsConfigs)
            {
                stationConfigurations.Add(JsonConvert.DeserializeObject<StationConfiguration>(config.ContentValue));
            }
            return stationConfigurations;
        }
        public IEnumerable<ChannelConfiguration> GetChannelsConfigs()
        {
            List<ChannelConfiguration> channelConfigurations = new List<ChannelConfiguration>();
            var channelsConfig = configSettingService.GetConfigSettingsByGroupName(CPCB_GROUPNAME).Where(e => e.ContentName.StartsWith("ChannelConfiguration_"));
            foreach (var config in channelsConfig)
            {
                channelConfigurations.Add(JsonConvert.DeserializeObject<ChannelConfiguration>(config.ContentValue));
            }
            return channelConfigurations;
        }
        public IEnumerable<ChannelConfiguration> GetCPCBChannelsConfigsByStationId(int stationId)
        {
            return GetChannelsConfigs().Where(e => e.StationId == stationId);
        }
    }
}
