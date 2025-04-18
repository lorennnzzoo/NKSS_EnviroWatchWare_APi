using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("PCB")]
    public class PCBController : ApiController
    {
        private readonly PCBService pcbService;
        public PCBController(PCBService _pcbService)
        {
            pcbService = _pcbService;
        }

        [HttpGet]
        [Route("GetCPCBStationConfigurations")]
        public IHttpActionResult GetCPCBStationConfigurations()
        {
            try
            {
                var configurations = pcbService.GetCPCBStationsConfigs();
                if (configurations == null)
                {
                    return NotFound();
                }
                return Ok(configurations);
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetCPCBChannelConfigurationsByStation")]
        public IHttpActionResult GetCPCBChannelConfigurationsByStation(int stationId)
        {
            try
            {
                var configurations = pcbService.GetCPCBChannelsConfigsByStationId(stationId);
                if (configurations == null)
                {
                    return NotFound();
                }
                return Ok(configurations);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("CreateCPCBStationConfiguration")]
        public IHttpActionResult CreateCPCBStationConfiguration(Models.PCB.CPCB.StationConfiguration stationConfiguration)
        {
            try
            {
                pcbService.CreateCPCBStationConfig(stationConfiguration);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("CreateCPCBChannelConfiguration")]
        public IHttpActionResult CreateCPCBChannelConfiguration(Models.PCB.CPCB.ChannelConfiguration channelConfiguration)
        {
            try
            {
                pcbService.CreateCPCBChannelConfig(channelConfiguration);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateCPCBStationConfiguration")]
        public IHttpActionResult UpdateCPCBStationConfiguration(Models.PCB.CPCB.StationConfiguration stationConfiguration)
        {
            try
            {
                pcbService.UpdateCPCBStationConfig(stationConfiguration);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateCPCBChannelConfiguration")]
        public IHttpActionResult UpdateCPCBChannelConfiguration(Models.PCB.CPCB.ChannelConfiguration channelConfiguration)
        {
            try
            {
                pcbService.UpdateCPCBChannelConfig(channelConfiguration);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetCPCBStationConfigurationById")]
        public IHttpActionResult GetCPCBStationConfigurationById(string id)
        {
            try
            {
                var configuration = pcbService.GetCPCBStationConfigurationById(id);
                if (configuration == null)
                {
                    return NotFound();
                }
                return Ok(configuration);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetCPCBChannelConfigurationById")]
        public IHttpActionResult GetCPCBChannelConfigurationById(string id)
        {
            try
            {
                var configuration = pcbService.GetCPCBChannelConfigurationById(id);
                if (configuration == null)
                {
                    return NotFound();
                }
                return Ok(configuration);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteCPCBStationConfiguration")]
        public IHttpActionResult DeleteCPCBStationConfiguration(string id)
        {
            try
            {
                pcbService.DeleteCPCBStationConfig(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteCPCBChannelConfiguration")]
        public IHttpActionResult DeleteCPCBChannelConfiguration(string id)
        {
            try
            {
                pcbService.DeleteCPCBChannelConfig(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateCPCBUploadSettings")]
        public IHttpActionResult UpdateCPCBUploadSettings(Models.PCB.UploadSettings uploadSettings)
        {
            try
            {
                pcbService.UpdateCPCBUploadSettings(uploadSettings);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetCPCBUploadSettings")]
        public IHttpActionResult GetCPCBUploadSettings()
        {
            try
            {
                var settings = pcbService.GetCPCBUploadSettings();
                if (settings == null)
                {
                    return NotFound();
                }
                return Ok(settings);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetCPCBChannelSyncStatuses")]
        public IHttpActionResult GetCPCBChannelSyncStatuses()
        {
            try
            {
                var syncStatuses = pcbService.GetCPCBChannelSyncStatuses();
                if (syncStatuses == null)
                {
                    return NotFound();
                }
                return Ok(syncStatuses);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
    }
}
