using Models;
using Services.Interfaces;
using Services.Interfaces.EnviroMonitor;
using System;
using System.Collections.Generic;
using System.Linq;
using log4net;
using log4net.Config;

namespace Services.Services.EnviroMonitor
{
    public class EnviroMonitorService : IEnviroMonitorService
    {
        private static readonly ILog logger = LogManager.GetLogger(typeof(EnviroMonitorService));
        private readonly IConfigSettingService configSettingService;
        private readonly IStationService stationService;
        private readonly IAnalyzerService analyzerService;
        private readonly IChannelDataFeedService channelDataFeedService;
        private readonly IChannelService channelService;       
        public EnviroMonitorService(IConfigSettingService _configSettingService, IStationService _stationService, IAnalyzerService _analyzerService, IChannelService _channelService, IChannelDataFeedService _channelDataFeedService)
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
            configSettingService = _configSettingService;
            stationService = _stationService;
            analyzerService = _analyzerService;
            channelService = _channelService;
            channelDataFeedService = _channelDataFeedService;
        }
        public void Run(List<ConfigSetting> configSettings)
        {
            logger.Info("Loading stations");
            List<Station> stations = LoadStations();
            if (!stations.Any())
            {
                logger.Warn("No stations found");
                return;
            }
            logger.Info($"Stations found : {string.Join(",",stations.Select(e=>e.Name))}");
            ProcessStations(stations);
        }

        private void ProcessStations(List<Station> stations)
        {
            
            foreach(Station station in stations)
            {
                logger.Info($"Processing station : {station.Name}");
                logger.Info($"Loading channels");
                List<Channel> channels = LoadChannels((int)station.Id);
                if (!channels.Any())
                {
                    logger.Warn("No channels found");
                    continue;
                }
                logger.Info($"Channels found : {string.Join(",", channels.Select(e => e.Name))}");
                ProcessChannels(channels,station);
            }
        }
        private void ProcessChannels(List<Channel> channels,Station station)
        {
            foreach(Channel channel in channels)
            {
                logger.Info($"Processing Channel : {channel.Name}");
                logger.Info($"Loading analyzer");
                Analyzer analyzer = GetAnalyzer((int)channel.ProtocolId);
                if (analyzer == null)
                {
                    logger.Warn("No analyzer found");
                    continue;
                }
                logger.Info($"Analyzer found : {analyzer.ProtocolType}");
                decimal? value = Protocol.Process.FetchAnalyzerValue(analyzer, channel);
                if (!value.HasValue)
                {
                    logger.Warn($"null value received");
                }
                else
                {
                    logger.Info($"Value received : {value}");
                    channelDataFeedService.InsertChannelData((int)channel.Id, (decimal)value, DateTime.Now, "");
                }
            }
        }

        private Analyzer GetAnalyzer(int analyzerId)
        {
            return analyzerService.GetAnalyzerById(analyzerId);
        }
        private List<Station> LoadStations()
        {
            return stationService.GetAllStations().ToList();
        }
        private List<Channel> LoadChannels(int stationId)
        {
            return channelService.GetAllChannelsByStationId(stationId).ToList();
        }
    }
}
