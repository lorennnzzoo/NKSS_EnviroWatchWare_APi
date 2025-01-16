using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("ChannelType")]
    public class ChannelTypeController : ApiController
    {
        private readonly ChannelTypeService channel_type_service;
        private Helpers.Validator validator = new Helpers.Validator();
        public ChannelTypeController(ChannelTypeService _channel_type_service)
        {
            this.channel_type_service = _channel_type_service;
        }
        [HttpGet]
        [Route("GetChannelType")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var channelType = channel_type_service.GetChannelTypeById(id);
                if (channelType == null)
                    return NotFound();
                return Ok(channelType);
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
        [Route("GetAllChannelTypes")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var channelTypes = channel_type_service.GetAllChannelTypes();
                return Ok(channelTypes);
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
        [Route("AddChannelType")]
        public IHttpActionResult Add(Post.ChannelType channelType)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var result = validator.ValidateProperties(channelType);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                channel_type_service.CreateChannelType(channelType);
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

        [HttpPut]
        [Route("UpdateChannelType")]
        public IHttpActionResult Update(ChannelType channelType)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var result = validator.ValidateProperties(channelType);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                channel_type_service.UpdateChannelType(channelType);
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

        [HttpDelete]
        [Route("DeleteChannelType")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                channel_type_service.DeleteChannelType(id);
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
