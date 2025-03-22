using Models;
using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class ConfigurationService : IConfigurationService
    {
        private readonly IConfigurationRepository _configurationRepository;
        private readonly IChannelRepository _channelRepository;
        private readonly IStationRepository _stationRepository;
        private readonly ICompanyRepository _companyRepository;

        private readonly ConfigSettingService configSettingService;
        private readonly string contractsGroupName="ApiContract";
        public ConfigurationService(IConfigurationRepository configurationRepository, ConfigSettingService _configSettingService, IChannelRepository channelRepository, IStationRepository stationRepository, ICompanyRepository companyRepository)
        {
            _configurationRepository = configurationRepository;
            configSettingService = _configSettingService;
            _channelRepository = channelRepository;
            _stationRepository = stationRepository;
            _companyRepository = companyRepository;
        }
        public Dictionary<string, object> GetConfiguration()
        {
            System.Data.DataSet dataSet = _configurationRepository.GetConfigurationDataSet();
            var configuration = new Dictionary<string, object>
                                        {
                                            { "Configuration", new Dictionary<string, object>() }
                                        };
            if (dataSet.Tables.Count > 0)
            {
                

                var configurationElement = (Dictionary<string, object>)configuration["Configuration"];

                
                var companies = new List<Dictionary<string, object>>();
                foreach (DataRow companyRow in dataSet.Tables[0].Rows)
                {
                    var companyElement = new Dictionary<string, object>();

                    
                    foreach (DataColumn column in dataSet.Tables[0].Columns)
                    {
                        companyElement[column.ColumnName] = ConvertValueBasedOnType(companyRow[column], column.DataType);
                    }

                    
                    var stations = new List<Dictionary<string, object>>();
                    foreach (DataRow stationRow in dataSet.Tables[1].Rows)
                    {
                        if (stationRow.Field<int>("CompanyId") == companyRow.Field<int>("Id"))
                        {
                            var stationElement = new Dictionary<string, object>();

                            
                            foreach (DataColumn column in dataSet.Tables[1].Columns)
                            {
                                stationElement[column.ColumnName] = ConvertValueBasedOnType(stationRow[column], column.DataType);
                            }

                            
                            var monitoringTypes = new List<Dictionary<string, object>>();
                            foreach (DataRow monitoringTypeRow in dataSet.Tables[3].Rows)
                            {
                                if (monitoringTypeRow.Field<int>("Id") == stationRow.Field<int>("MonitoringTypeId"))
                                {
                                    var monitoringTypeElement = new Dictionary<string, object>();
                                    foreach (DataColumn column in dataSet.Tables[3].Columns)
                                    {
                                        monitoringTypeElement[column.ColumnName] = ConvertValueBasedOnType(monitoringTypeRow[column], column.DataType);
                                    }
                                    monitoringTypes.Add(monitoringTypeElement);
                                }
                            }
                            stationElement["MonitoringType"] = monitoringTypes;

                            
                            var channels = new List<Dictionary<string, object>>();
                            foreach (DataRow channelRow in dataSet.Tables[2].Rows)
                            {
                                if (channelRow.Field<int>("StationId") == stationRow.Field<int>("Id"))
                                {
                                    var channelElement = new Dictionary<string, object>();

                                    
                                    foreach (DataColumn column in dataSet.Tables[2].Columns)
                                    {
                                        channelElement[column.ColumnName] = ConvertValueBasedOnType(channelRow[column], column.DataType);
                                    }

                                    
                                    var analyzers = new List<Dictionary<string, object>>();
                                    foreach (DataRow analyzerRow in dataSet.Tables[6].Rows)
                                    {
                                        if (analyzerRow.Field<int>("Id") == channelRow.Field<int>("ProtocolId"))
                                        {
                                            var analyzerElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[6].Columns)
                                            {
                                                analyzerElement[column.ColumnName] = ConvertValueBasedOnType(analyzerRow[column], column.DataType);
                                            }
                                            analyzers.Add(analyzerElement);
                                        }
                                    }
                                    channelElement["Analyzer"] = analyzers;

                                    
                                    var oxides = new List<Dictionary<string, object>>();
                                    foreach (DataRow oxideRow in dataSet.Tables[5].Rows)
                                    {
                                        if (oxideRow.Field<int>("Id") == channelRow.Field<int>("OxideId"))
                                        {
                                            var oxideElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[5].Columns)
                                            {
                                                oxideElement[column.ColumnName] = ConvertValueBasedOnType(oxideRow[column], column.DataType);
                                            }
                                            oxides.Add(oxideElement);
                                        }
                                    }
                                    channelElement["Oxide"] = oxides;

                                    
                                    var channelTypes = new List<Dictionary<string, object>>();
                                    foreach (DataRow channelTypeRow in dataSet.Tables[4].Rows)
                                    {
                                        if (channelTypeRow.Field<int>("Id") == channelRow.Field<int>("ChannelTypeId"))
                                        {
                                            var channelTypeElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[4].Columns)
                                            {
                                                channelTypeElement[column.ColumnName] = ConvertValueBasedOnType(channelTypeRow[column], column.DataType);
                                            }
                                            channelTypes.Add(channelTypeElement);
                                        }
                                    }
                                    channelElement["ChannelType"] = channelTypes;

                                    
                                    var scalingFactors = new List<Dictionary<string, object>>();
                                    foreach (DataRow scalingFactorRow in dataSet.Tables[7].Rows)
                                    {
                                        if (scalingFactorRow.Field<int>("Id") == channelRow.Field<int>("ScalingFactorId"))
                                        {
                                            var scalingFactorElement = new Dictionary<string, object>();
                                            foreach (DataColumn column in dataSet.Tables[7].Columns)
                                            {
                                                scalingFactorElement[column.ColumnName] = ConvertValueBasedOnType(scalingFactorRow[column], column.DataType);
                                            }
                                            scalingFactors.Add(scalingFactorElement);
                                        }
                                    }
                                    channelElement["ScalingFactor"] = scalingFactors;

                                    channels.Add(channelElement);
                                }
                            }
                            stationElement["Channels"] = channels;

                            stations.Add(stationElement);
                        }
                    }
                    companyElement["Stations"] = stations;

                    companies.Add(companyElement);
                }
                configurationElement["Companies"] = companies;

                
                var licenses = new List<Dictionary<string, object>>();
                foreach (DataRow licenseRow in dataSet.Tables[8].Rows)
                {
                    var licenseElement = new Dictionary<string, object>();
                    foreach (DataColumn column in dataSet.Tables[8].Columns)
                    {
                        licenseElement[column.ColumnName] = ConvertValueBasedOnType(licenseRow[column], column.DataType);
                    }
                    licenses.Add(licenseElement);
                }
                configurationElement["Licenses"] = licenses;

                
                var configSettings = new List<Dictionary<string, object>>();
                foreach (DataRow configSettingRow in dataSet.Tables[9].Rows)
                {
                    var configSettingElement = new Dictionary<string, object>();
                    foreach (DataColumn column in dataSet.Tables[9].Columns)
                    {
                        configSettingElement[column.ColumnName] = ConvertValueBasedOnType(configSettingRow[column], column.DataType);
                    }
                    configSettings.Add(configSettingElement);
                }
                configurationElement["ConfigSettings"] = configSettings;

            }
                return configuration;
        }
        private static object ConvertValueBasedOnType(object value, Type type)
        {
            if (value == DBNull.Value)
                return null;

            if (type == typeof(int) || type == typeof(long) || type == typeof(short))
                return Convert.ToInt64(value);

            if (type == typeof(decimal) || type == typeof(float) || type == typeof(double))
                return Convert.ToDecimal(value);

            if (type == typeof(DateTime))
                return Convert.ToDateTime(value).ToString("yyyy-MM-ddTHH:mm:ss");

            if (type == typeof(bool))
                return Convert.ToBoolean(value);

            return value.ToString(); 
        }

        public IEnumerable<ConfigSetting> GetApiContracts()
        {
            return configSettingService.GetConfigSettingsByGroupName(contractsGroupName);
        }

        public Dictionary<string, object> GetUploadConfig(int companyId, List<int> StationsId, List<int> ChannelsId)
        {
            Dictionary<int, List<int>> StationChannelPairs = new Dictionary<int, List<int>>();
            Models.Company companyDetail = _companyRepository.GetById(companyId);
            List<Models.Station> stationsOfCompany = new List<Models.Station>();
            List<Models.Channel> channelsOfStation = new List<Models.Channel>();


            if (StationsId != null && StationsId.Count > 0 && ChannelsId != null && ChannelsId.Count > 0)
            {
                foreach (int stationId in StationsId)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);


                    List<int> matchingValues = channelIds.Intersect(ChannelsId).ToList();


                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange(matchingValues.Count > 0 ? _channelRepository.GetAll().Where(e => matchingValues.Contains(Convert.ToInt32(e.Id))).ToList() : _channelRepository.GetAll().ToList());
                    StationChannelPairs.Add(stationId, matchingValues.Count > 0 ? matchingValues : channelIds);
                }
            }

            else if (StationsId != null && StationsId.Count > 0)
            {
                foreach (int stationId in StationsId)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);
                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange(_channelRepository.GetAll().Where(e => e.StationId == stationId).Where(e => e.Active == true).ToList());
                    StationChannelPairs.Add(stationId, channelIds);
                }
            }

            else
            {
                List<int> stationIds = _stationRepository.GetAll()
                                                         .Where(e => e.CompanyId == companyId).Where(e => e.Active = true)
                                                         .Select(e => e.Id).OfType<int>()
                                                         .ToList();

                foreach (int stationId in stationIds)
                {
                    List<int> channelIds = GetChannelIdsForStation(stationId);
                    stationsOfCompany.Add(_stationRepository.GetById(stationId));
                    channelsOfStation.AddRange(_channelRepository.GetAll().Where(e => e.StationId == stationId).Where(e => e.Active == true).ToList());
                    StationChannelPairs.Add(stationId, channelIds);
                }
            }

            var ids = channelsOfStation.ToList();
            var config = GenerateUploadConfigData(channelsOfStation);
            return config;
        }

        private List<int> GetChannelIdsForStation(int stationId)
        {
            return _channelRepository.GetAll()
                                     .Where(e => e.StationId == stationId).Where(e => e.Active = true)
                                     .Select(e => e.Id).OfType<int>()
                                     .ToList();
        }
        public Dictionary<string, object> GenerateUploadConfigData(List<Models.Channel> channelsOfStation)
        {
            if (channelsOfStation == null || !channelsOfStation.Any())
            {
                return new Dictionary<string, object> { { "error", "No channels found." } };
            }

            
            var stationIds = channelsOfStation.Select(c => c.StationId).Distinct().ToList();

            
            var stations = _stationRepository.GetAll()
                            .Where(s => stationIds.Contains(s.Id))
                            .ToList();

            
            var xmlConfig = new Dictionary<string, object>
    {
        { "Stations", new List<object>() }
    };

            foreach (var station in stations)
            {
                var channels = channelsOfStation
                                .Where(c => c.StationId == station.Id)
                                .Select(c => new Dictionary<string, object>
                                {
                            { "Id", c.Id },
                            { "Name", c.Name },
                            { "LoggingUnits", c.LoggingUnits }
                                })
                                .ToList();

                ((List<object>)xmlConfig["Stations"]).Add(new Dictionary<string, object>
        {
            { "Id", station.Id },
            { "Name", station.Name },
            { "Channels", channels }
        });
            }

            
            string jsonConfig = Newtonsoft.Json.JsonConvert.SerializeObject(xmlConfig);

            
            string generatedKey = Guid.NewGuid().ToString();

            
            

            configSettingService.CreateConfigSetting(new Models.Post.ConfigSetting
            {
                GroupName = contractsGroupName,
                ContentName = generatedKey,
                ContentValue = jsonConfig  
            });

            return xmlConfig; 
        }



    }
}
