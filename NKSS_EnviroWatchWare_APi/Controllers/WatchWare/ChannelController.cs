using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Admin")]
    [RoutePrefix("Channel")]
    public class ChannelController : ApiController
    {
        private readonly ChannelService channel_service;
        private Helpers.ChannelValidator channelValidator = new Helpers.ChannelValidator();
        public ChannelController(ChannelService _channel_service)
        {
            this.channel_service = _channel_service;
        }

        [HttpGet]
        [Route("GetChannel")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var channel = channel_service.GetChannelById(id);
                if (channel == null)
                    return NotFound();
                return Ok(channel);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetAllChannels")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var channels = channel_service.GetAllChannels();
                return Ok(channels);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetAllChannelsByStation")]
        public IHttpActionResult GetAllChannelsByStation(int stationId)
        {
            try
            {
                var channels = channel_service.GetAllChannelsByStationId(stationId);
                return Ok(channels);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetAllChannelsByAnalyzer")]
        public IHttpActionResult GetAllByAnalyzer(int protocolId)
        {
            try
            {
                var channels = channel_service.GetAllChannelsByProtocolId(protocolId);
                return Ok(channels);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("AddChannel")]
        public IHttpActionResult Add(Post.Channel channel)
        {
            try
            {
                //if (channel == null)
                //    return BadRequest("Invalid data.");
                var result = channelValidator.ValidateProperties(channel);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                channel_service.CreateChannel(channel);
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
        [Route("UpdateChannel")]        
        public IHttpActionResult Update(Channel channel)
        {
            try
            {
                //if (channel == null)
                //    return BadRequest("Invalid data.");
                var result = channelValidator.ValidateProperties(channel);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                channel_service.UpdateChannel(channel);
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
        [Route("DeleteChannel")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                channel_service.DeleteChannel(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
