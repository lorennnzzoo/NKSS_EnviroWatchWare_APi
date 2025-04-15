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
        public IHttpActionResult UpdateCPCBStationConfiguration(Models.PCB.CPCB.ChannelConfiguration channelConfiguration)
        {
            try
            {
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
    }
}
